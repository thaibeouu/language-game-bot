defmodule BotConsumer do
  use Nostrum.Consumer
  require Logger

  alias Nostrum.Api

  def start_link do
    Consumer.start_link(__MODULE__)
  end

  def handle_event({:MESSAGE_CREATE, msg, _ws_state}) do
    cid = msg.channel_id
    aid = msg.author.id
    aname = msg.author.username
    id = msg.id
    content = String.downcase(msg.content)

    states_table = :ets.lookup(:states, cid)
    lock = Mutex.await(BotMutex, states_table, 30000)
    current_state = (states_table != [] && List.first(states_table)) || {nil, nil, nil, false}

    {_, last_author_id, last_char, joined} = current_state

    cond do
      msg.author.bot ->
        :ignore

      content == "::ping" ->
        Api.create_message(cid, "PONG!")

      content == "::help" ->
        Api.create_message!(
          cid,
          "Commands list:\n`::join`\n`::leave`\n`::score`\n\nNo data will be persisted once the bot restarts."
        )

      content == "::score" ->
        scores_table = :ets.lookup(:scores, cid)
        {_, current_scores} = (scores_table != [] && List.first(scores_table)) || {nil, []}

        if current_scores != [] do
          mapped_scores =
            Enum.map(Enum.sort_by(current_scores, fn x -> elem(x, 1) end), fn x ->
              "#{elem(x, 0)}: #{elem(x, 1)} \n"
            end)

          Api.create_message!(cid, "```\n#{Enum.join(mapped_scores, "")}\n```")
        else
          Api.create_message!(cid, "No scores yet.")
        end

      content == "::join" && !joined ->
        Api.create_message(cid, "Command me senpai!")
        :ets.insert_new(:states, {cid, nil, nil, true})

      content == "::leave" && joined ->
        Api.create_message(cid, "Bye.")
        :ets.delete(:states, cid)
        :ets.delete(:dicts, cid)
        :ets.delete(:scores, cid)

      last_author_id == aid && joined ->
        bot_msg = Api.create_message!(cid, "Wait for it.")
        Api.bulk_delete_messages!(cid, [id, bot_msg.id])

      last_char != nil && String.first(content) != last_char && joined ->
        bot_msg = Api.create_message!(cid, "Pay attention!")

        spawn(fn ->
          Api.bulk_delete_messages!(cid, [id, bot_msg.id])
        end)

      String.match?(content, ~r/(\w)/) && joined ->
        {_, current_dict} = List.first(:ets.lookup(:dicts, cid), {[], []})

        if content in current_dict do
          bot_msg = Api.create_message!(cid, "Duplicated.")
          Api.bulk_delete_messages!(cid, [id, bot_msg.id])
        else
          if App.check(content) do
            spawn(fn ->
              :ets.insert(:states, {cid, aid, String.last(content), true})
            end)

            Mutex.release(BotMutex, lock)

            Api.create_reaction!(cid, id, "\xF0\x9F\x90\xB2")

            spawn(fn ->
              :ets.insert(
                :dicts,
                {cid,
                 (length(current_dict) > 0 && current_dict ++ [content]) ||
                   [content]}
              )
            end)

            spawn(fn ->
              scores_table = :ets.lookup(:scores, cid)

              {_, current_scores} = (scores_table != [] && List.first(scores_table)) || {nil, []}

              if current_scores != [] do
                current_author_score = Enum.find(current_scores, fn m -> elem(m, 0) == aname end)

                if current_author_score != nil do
                  score = elem(current_author_score, 1)
                  index = Enum.find_index(current_scores, fn m -> elem(m, 0) == aname end)

                  new_current_scores = List.replace_at(current_scores, index, {aname, score + 1})
                  :ets.insert(:scores, {cid, new_current_scores})
                else
                  new_current_scores = List.insert_at(current_scores, -1, {aname, 1})
                  :ets.insert(:scores, {cid, new_current_scores})
                end
              else
                :ets.insert(:scores, {cid, [{aname, 1}]})
              end
            end)
          else
            bot_msg = Api.create_message!(cid, "Not even close.")
            Api.bulk_delete_messages!(cid, [id, bot_msg.id])
          end
        end

      true ->
        :noop
    end
  end

  def handle_event(_event) do
    :noop
  end
end

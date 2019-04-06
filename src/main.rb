require 'discordrb'

bot = Discordrb::Bot.new token:
 'NTYzOTIzNTU4ODg4Mzc0Mjgy.XKgZ7A.wV0v_ojx9sZeyeWD2xTfMnz5DzY'

bot.message(content: 'Ping!') do |event|
  event.respond 'Pong!'
end

bot.run

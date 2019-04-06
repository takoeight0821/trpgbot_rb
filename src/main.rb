$LOAD_PATH.unshift __dir__
require 'discordrb'
require 'bcdice_wrap'

class UnsupportedDicebot < StandardError
end

class CommandError < StandardError
end

bot = Discordrb::Commands::CommandBot.new token:
 'NTYzOTIzNTU4ODg4Mzc0Mjgy.XKgZ7A.wV0v_ojx9sZeyeWD2xTfMnz5DzY', prefix: '!'

env_table = {}

def make_bcdice(system, command)
  dicebot = BCDice::DICEBOTS[system]

  raise UnsupportedDicebot if dicebot.nil?

  raise CommandError if command.nil? || command.empty?

  bcdice = BCDiceMaker.new.newBcDice
  bcdice.setDiceBot(dicebot)
  bcdice.setMessage(command)
  bcdice.setDir('bcdice/extratables', system)
  bcdice.setCollectRandResult(true)
  bcdice
end

def diceroll(system, command)
  bcdice = make_bcdice(system, command)

  result, secret = bcdice.dice_command
  dices = bcdice.getRandResults.map { |dice| { faces: dice[1], value: dice[0] } }

  puts "DEBUG: #{[system, command]} #{[result, secret, dices]}"

  raise CommandError if result.nil? || result == '1'

  [result, secret, dices]
end

bot.command :roll do |event, *args|
  env_table[event.channel.id] ||= {}
  env_table[event.channel.id][:system] ||= 'DiceBot'
  result, secret, _dices = diceroll(env_table[event.channel.id][:system], args.join(' '))
  msg = BCDice::DICEBOTS[env_table[event.channel.id][:system]].gameName + result

  if secret
    event.user.pm msg
    nil
  else
    msg
  end
end

bot.command :set_system do |event, system|
  env_table[event.channel.id] ||= {}
  env_table[event.channel.id][:system] = system
  "set system #{system} (#{BCDice::DICEBOTS[system].gameName})"
end

bot.command :show_env do |event|
  env_table[event.channel.id] ||= {}
  env_table[event.channel.id].to_s
end

bot.run

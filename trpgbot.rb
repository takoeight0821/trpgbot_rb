require 'discordrb'

$LOAD_PATH.unshift File.join(__dir__, 'BCDice', 'src')
require_relative './BCDice/src/bcdiceCore'
require_relative './BCDice/src/diceBot/DiceBot'
require_relative './BCDice/src/diceBot/DiceBotLoader'

class BCDice
  DICEBOTS = (DiceBotLoader.collectDiceBots + [DiceBot.new]).map do |dice_bot|
    [dice_bot.gameType, dice_bot]
  end.sort.to_h.freeze

  SYSTEMS = DICEBOTS.keys.sort.freeze

  NAMES = DICEBOTS.map { |game_type, dice_bot| { system: game_type, name: dice_bot.gameName } }
                  .freeze
end

module Trpgbot
  class UnsupportedDicebot < StandardError; end

  class CommandError < StandardError; end

  # TRPG bot on Discord
  class Bot < Discordrb::Commands::CommandBot
    # @return [Hash] bot config for each channels
    attr_accessor :env_table

    # @param id [Integer] channel id
    # @return [Hash] bot config for the channel
    def env(id)
      @env_table ||= {}
      @env_table[id] ||= { system: 'DiceBot' }
      @env_table[id]
    end

    # @param id [Integer] channel id
    # @param key [Symbol] key of config
    # @param val [Object] new value
    def set_env(id, key, val)
      @env_table ||= {}
      @env_table[id] ||= { system: 'DiceBot' }
      @env_table[id][key] = val
    end

    def make_bcdice(system, command)
      dicebot = BCDice::DICEBOTS[system]

      raise UnsupportedDicebot if dicebot.nil?

      raise CommandError if command.nil? || command.empty?

      @bcdice ||= BCDiceMaker.new.newBcDice
      @bcdice.setDiceBot(dicebot)
      @bcdice.setMessage(command)
      @bcdice.setDir('bcdice/extratables', system)
      @bcdice.setCollectRandResult(true)
      @bcdice
    end

    def diceroll(id, command)
      system = env(id)[:system]
      bcdice = make_bcdice(system, command)

      result, secret = bcdice.dice_command

      puts "DEBUG: #{[system, command]} #{[result, secret]}"

      raise CommandError if result.nil? || result == '1'

      [result, secret]
    end
  end
end

bot = Bot.new(
  token: ENV['BOT_TOKEN'],
  prefix: '!',
  ignore_bots: true
)

bot.command [:roll, :r, :dice] do |event, dice, system = nil|
  save = bot.env_table

  begin
    bot.set_env(event.channel.id, :system, system) unless system.nil?

    result, secret = bot.diceroll(event.channel.id, dice)
    msg = BCDice::DICEBOTS[bot.env(event.channel.id)[:system]].gameName + result

    bot.env_table = save
    if secret
      event.user.pm msg
    else
      event << msg
    end
  rescue CommandError => e
    event << e.to_s
  end

  nil
end

bot.command :set_system do |event, system|
  bot.set_env(event.channel.id, :system, system)
  "set system #{system} (#{BCDice::DICEBOTS[system].gameName})"
end

bot.command :show_env do |event|
  bot.env(event.channel.id).to_s
end

bot.run

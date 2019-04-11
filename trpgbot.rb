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

  attr_reader :counterInfos
end

module TRPGBot
  class UnsupportedDicebot < StandardError; end

  class CommandError < StandardError; end

  # TRPG bot on Discord
  class Bot < Discordrb::Commands::CommandBot
    # @return [Hash] bot config for each channels
    attr_accessor :env_table
    # @return [BCDice]
    attr_reader :bcdice
    # @return [Hash] {channel_id => {character_name => {tag => value}}}
    attr_accessor :count_info_table

    def initialize(*args)
      super(*args)
      @bcdice = BCDiceMaker.new.newBcDice
      @env_table = {}
      @count_info_table = {}
    end

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

    # @param id [Integer] channel id
    # @return [Hash] {character_name => {tag => value}}
    def count_info(id)
      @count_info_table[id] ||= {}
      @count_info_table[id]
    end

    # @param id [Integer] channel id
    # @param name [String] character name
    # @param tag [String] tag
    # @param val [Object] new value
    def set_count_info(id, name, tag, val)
      raise CommandError if name.nil? || tag.nil? || val.nil?

      @count_info_table[id] ||= {}
      @count_info_table[id][name] ||= {}
      @count_info_table[id][name][tag] = val.to_i
    end

    def modify_count_info(id, name, tag)
      @count_info_table[id] ||= {}
      @count_info_table[id][name] ||= {}
      set_count_info(id, name, tag, yield(@count_info_table[id][name][tag]))
    end

    # @param id [Integer] channel id
    # @return [Array]
    def show_count_info(id, name = nil, tag = nil)
      output = []
      name = nil if name == 'all'
      count_info(id).each do |n, counters|
        next if !name.nil? && name != n

        byname = ''
        counters.each do |t, val|
          next if !tag.nil? && tag != t

          byname << ', ' unless byname.empty?
          byname << "#{t}:#{val}"
        end
        output << "#{n}(#{byname})"
      end
      output
    end

    def update_bcdice(system, command)
      dicebot = BCDice::DICEBOTS[system]

      raise UnsupportedDicebot if dicebot.nil?

      raise CommandError if command.nil? || command.empty?

      @bcdice.setDiceBot(dicebot)
      @bcdice.setMessage(command)
      @bcdice.setDir('bcdice/extratables', system)
      @bcdice.setCollectRandResult(true)
      @bcdice
    end

    def diceroll(id, command)
      system = env(id)[:system]
      bcdice = update_bcdice(system, command)

      result, secret = bcdice.dice_command

      puts "DICEROLL: #{[system, command]} #{[result, secret]}"

      raise CommandError if result.nil? || result == '1'

      [result, secret]
    end
  end
end

bot = TRPGBot::Bot.new(
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
  rescue TRPGBot::CommandError => e
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

bot.command :show_count do |event, name, tag|
  bot.show_count_info(event.channel.id, name, tag).each do |o|
    event << o
  end
  nil
end

bot.command :set_count do |event, name, tag, val|
  begin
    bot.set_count_info(event.channel.id, name, tag, val)
    "#{name}:#{tag} = #{val.to_i}"
  rescue TRPGBot::CommandError => e
    event << e.to_s
  end
end

bot.command :inc_count do |event, name, tag, val|
  output = ''
  bot.modify_count_info(event.channel.id, name, tag) do |v|
    tmp = v + val.to_i
    output << "#{name}:#{tag} = #{v} -> #{tmp}"
    tmp
  end
  output
end

bot.run

# frozen_string_literal: true

$LOAD_PATH.unshift File.join(__dir__, '..', 'BCDice', 'src')
require_relative '../BCDice/src/bcdiceCore'
require_relative '../BCDice/src/diceBot/DiceBot'
require_relative '../BCDice/src/diceBot/DiceBotLoader'

class BCDice
  DICEBOTS = (DiceBotLoader.collectDiceBots + [DiceBot.new]).map do |dice_bot|
    [dice_bot.gameType, dice_bot]
  end.sort.to_h.freeze

  SYSTEMS = DICEBOTS.keys.sort.freeze

  NAMES = DICEBOTS.map { |game_type, dice_bot| { system: game_type, name: dice_bot.gameName } }
                  .freeze
end

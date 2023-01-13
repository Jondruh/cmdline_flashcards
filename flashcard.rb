require 'pry'
require 'date'
# Filenames for the cards must be formatted as such:
# year-month-day_currentbox_cardtopic.md
#       ^
# date to review

TAB = "\t".freeze
ESCAPE = "\e".freeze
RETURN = "\r".freeze
BACKSPACE = "\u007F".freeze

LEITNER_SCHEDULE = { 1 => 1, 2 => 2, 3 => 4, 4 => 8, 5 => 16, 6 => 32, 7 => 64 }.freeze

def highlight_text(text)
  "\e[40m" + text + "\e[0m"
end

def fade_text(text)
  "\e[30m" + text + "\e[0m"
end

# Formats some markdown for printing to console
# Currently only handles code blocks
def format_code_blocks(string)
  triple_pairs = string.scan(/```/).count / 2
  triple_pairs.times do
    string.sub!(/```/, "\e[40m")
    string.sub!(/```/, "\e[0m")
  end

  single_pairs = string.scan(/`/).count / 2
  single_pairs.times do
    string.sub!(/`/, "\e[40m")
    string.sub!(/`/, "\e[0m")
  end
  string
end

# Iterates through each card of the array handed to it
def study_cards(cards)
  cards.shuffle.each do |card|
    front, back = fetch_card(card)

    system 'clear'
    puts "\e[30m" + card + "\e[0m"
    puts

    puts format_code_blocks(front)
    puts '_' * 80

    puts 'Ready to see the back? Press Enter'.center(80)
    gets.chomp

    puts format_code_blocks(back)
    puts '_' * 80

    puts "To edit this card press ('E')".center(80)
    puts "Previous box ('P') // Next box ('N') // This box ('T')".center(80)

    input = gets.chomp

    case input.downcase
    when 'e'
      system "$EDITOR #{card}"
    else
      next_study_date(input, card)
    end
  end
end

# rewrites the card file name to indicate the box and next study date
def next_study_date(input, card)
  _date, box, name = card.split('_')

  box = box.to_i
  case input.downcase
  when 'p' then box -= 1
  when 'n' then box += 1
  end

  date = Date.today + LEITNER_SCHEDULE[box]

  new_name = './cards/' + [date, box, name].join('_')

  File.rename(card, new_name)
end

def fetch_card(card)
  File.open(card) do |file|
    front, back = file.read.split('<card_bottom_flag>')
    return front, back
  end
end

# returns an array of all due cards
def due_cards
  all_cards = Dir['./cards/*md']
  all_cards.select do |file_name|
    date = file_name.split('_')[0]
    Date.parse(date) <= Date.today
  end
end

def display_completion_list(candidate_list, selection = nil)
  puts
  candidate_list.each_with_index do |word, ind|
    if ind == selection
      puts fade_text(word)
    else
      puts highlight_text(word)
    end
  end
end

def auto_complete(candidate_list, char)
  selection = -1

  while char == TAB
    # selection = 0 unless (0...candidate_list.length).include(selection)
    selection += 1
    selection = 0 if selection >= candidate_list.length
    input = candidate_list[selection]
    card_name_prompt
    print input
    display_completion_list(candidate_list, selection)
    char = fetch_char
  end

  [input, char]
end

def fetch_char
  system 'stty raw -echo' # Raw mode, no echo
  char = STDIN.getc
  system 'stty -raw echo' # reset terminal mode
  char
end

def card_name_prompt
  system 'clear'
  puts 'What is your card name? (CamelCaseOnlyPlease)'
end

def update_candidate_list(name_list, input)
  name_list.select { |name| name.start_with?(input) }.sort
end

def create_card_name(name_list)
  card_name_prompt
  input = ''

  loop do
    candidate_list = update_candidate_list(name_list, input)
    char = fetch_char

    input, char = auto_complete(candidate_list, char) if char == TAB

    if char == ESCAPE
      input = ESCAPE
      break
    elsif char == RETURN
      break
    elsif char == BACKSPACE
      input = input[0...-1]
    else
      input += char
    end

    card_name_prompt
    print input

    candidate_list = update_candidate_list(name_list, input)
    display_completion_list(candidate_list)
  end
  input
end

def create_card
  card_name = nil

  card_names = Dir['./cards/*md'].map { |card| card.split('_')[2].delete_suffix('.md') }

  loop do
    card_name = create_card_name(card_names)
    break if card_name == ESCAPE

    if card_name.chars.any?(/[^a-zA-Z0-9]/)
      puts 'Sorry, only letters and numbers allowed in the card name.'
      gets.chomp
    elsif card_names.include?(card_name)
      puts 'There is already a card with that name, please pick a different name'
      gets.chomp
    else
      break
    end
  end

  return nil if card_name == ESCAPE

  # create a file with that name
  card = File.new("./cards/#{Date.today}_1_#{card_name}.md", 'w')
  path = card.path

  card.puts '<card_bottom_flag>'

  card.close

  # Uses default linux editor
  system "$EDITOR #{path}"
end

puts 'Welcome to the flashcard program'

loop do
  cards = due_cards

  puts 'What would you like to do?'
  puts '1) Create a card'
  puts "2) Review your cards (#{cards.size} cards to review)"
  puts '3) Exit the program'

  input = gets.chomp

  case input
  when '1' then create_card
  when '2' then study_cards(cards)
  when '3' then break
  end
end

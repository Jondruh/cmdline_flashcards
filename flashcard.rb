require 'pry'
require 'date'
# Filenames for the cards must be formatted as such:
# year-month-day_currentbox_cardtopic.md
#       ^
# date to review

LEITNER_SCHEDULE = {1 => 1, 2 => 2, 3 => 4, 4 => 8, 5 => 16, 6 => 32, 7 => 64}

def study_cards(cards) #Iterates through each card of the array handed to it
  cards.shuffle.each do |card|
    front, back  = fetch_card(card)

    system "clear"
    puts "\e[30m" + card + "\e[0m"
    puts

    puts format_code_blocks(front)
    puts "_" * 80

    puts "Ready to see the back? Press Enter".center(80)
    gets.chomp

    puts format_code_blocks(back)
    puts "_" * 80

    puts "To edit this card press ('E')".center(80)
    puts "Previous box ('P') // Next box ('N') // This box ('T')".center(80)

    input = gets.chomp

    case input.downcase
    when 'e' then 
      system "$EDITOR #{card}"
    else
      next_study_date(input, card)
    end

  end
end

def next_study_date(input, card) #rewrites the card file name to indicate the box and next study date

  date, box, name = card.split("_")

  box = box.to_i
  case input.downcase
  when 'p' then box -= 1
  when 'n' then box += 1
  end

  date = Date.today + LEITNER_SCHEDULE[box]

  new_name = "./cards/" + [date, box, name].join("_")

  File.rename(card, new_name)
end

# Formats some markdown for printing to console
# Currently only handles code blocks
def format_code_blocks(string)
  triple_pairs  = string.scan(/```/).count / 2
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

def fetch_card(card)
  File.open(card) do |file|
    front, back = file.read.split("<card_bottom_flag>")
    return front, back
  end
end

def due_cards #returns an array of all due cards
  all_cards = Dir["./cards/*md"]
  all_cards.select do |file_name|
    date = file_name.split('_')[0]
    Date.parse(date) <= Date.today
  end
end

def create_card_name(name_list)
  input = ""
  puts "All card names:"
  puts name_list.sort

  loop do
    system "stty raw -echo" #Raw mode, no echo
    char = STDIN.getc
    system "stty -raw echo" #reset terminal mode

    break if char == "\r"

    if char == "\u007F"
      input.slice!(-1) # "\u007F" is backspace
    else
      input = input + char
    end

    system "clear"
    print input
    puts
    puts name_list.select { |name| name.start_with?(input) }.sort
    # name_list.include?(input) ? puts("\nName already exists") : puts("\nValid name")
  end
  input
end

def create_card
  puts "What is your card name? (CamelCaseOnlyPlease)"
  card_name = nil

  card_names = Dir["./cards/*md"].map { |card| card.split('_')[2] }

  loop do
    card_name = create_card_name(card_names)
    if card_name.chars.any?(/[^a-zA-Z0-9]/)
      puts "Sorry, only letters and numbers allowed in the card name."
    elsif card_names.include?(card_name + ".md")
      puts "There is already a card with that name, please pick a different name"
    else
      break
    end
  end

  #create a file with that name
  card = File.new("./cards/#{Date.today}_1_#{card_name}.md", "w")
  path = card.path

  card.puts "<card_bottom_flag>"

  card.close

  #Uses default linux editor
  system "$EDITOR #{path}"
end

puts "Welcome to the flashcard program"

loop do
  cards = due_cards

  puts "What would you like to do?"
  puts "1) Create a card"
  puts "2) Review your cards (#{cards.size} cards to review)"
  puts "3) Exit the program"

  input = gets.chomp

  case input
  when '1' then create_card
  when '2' then study_cards(cards)
  when '3' then break
  end

end



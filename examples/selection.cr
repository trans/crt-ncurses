require "../src/cdk"

NCurses.start
NCurses.cbreak
NCurses.no_echo
CDK::Draw.init_cdk_color

cdkscreen = CDK::Screen.new(NCurses.stdscr)

items = ["Apples", "Bananas", "Cherries", "Dates", "Elderberries", "Figs"]
choices = ["[ ] ", "[*] "]

selection = CDK::Selection.new(cdkscreen, CDK::CENTER, CDK::CENTER,
  CDK::RIGHT, 12, 30,
  "</B>Select Fruits",
  items, items.size, choices, choices.size,
  LibNCurses::Attribute::Reverse.value.to_i32,
  true, false)

result = selection.activate

selection_results = selection.selections

selection.destroy
cdkscreen.destroy
CDK::Screen.end_cdk

if result >= 0
  puts "Selections:"
  items.each_with_index do |item, i|
    puts "  #{item}: #{selection_results[i] > 0 ? "Yes" : "No"}"
  end
else
  puts "Cancelled."
end

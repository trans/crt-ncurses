CDK-style markup. When fmt: true, strings like </B>Hello</!B> get parsed by char2chtype into an array of chtypes — each entry is a    
  character ord OR'd with ncurses attribute bits (bold, color, etc.). That's why the chtype-per-character approach exists.              
                                                                                                                                        
  Plain lines (fmt: false) have no markup — they're just text. Those are the ones that get unnecessarily decomposed into individual     
  ords, breaking multi-byte characters. Only those need the add_str fix.                                                                
                                                                                                                                        
❯ First off </B>Hello</!B> is not used any more, we switched it to `[bold]Hello[/]`.  Second, does formating *have* to be make an       
  array of chtyes, ord OR'd with ncurses attribute bits? -- Hmm... I guess that's the only way to get those character effects?          
                                                                                                                                        
● Not the only way. You can also use wattron/wattroff around waddstr:                                                                   
                                                                                                                                        
  wattron(BOLD)                                                                                                                         
  waddstr("Hello")
  wattroff(BOLD)                                                                                                                        
  waddstr(" world")                                                                                

  This handles multi-byte characters correctly AND gives per-segment formatting. It's actually cleaner than the chtype array — parse
  markup into [{text, attrs}] segments, then loop with attron/addstr/attroff.

  But that's a bigger CRT refactor. For the quick fix now, we just need the plain text path to use add_str instead of char-by-char
  mvwaddch. Want me to do just the quick fix, or go ahead and refactor both paths?


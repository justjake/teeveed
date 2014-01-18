annyang = window.annyang

greeting = '(?:ok|okay|hello)'
tv = '(?:teevee|tv|television)'
keyword = greeting + '\\s' + tv

just_keyword = new RegExp('^' + keyword + '$', 'i')
keyword_and_phrase = new RegExp('^' + keyword + '\\s(.+)', 'i')

window.regexes = [just_keyword, keyword_and_phrase]

textbox = ->
  window.document.getElementById('q')

form = ->
  window.document.getElementById('form')

callback = (text)->
  # the wake-up phrase was spoken!
  window.console.log("detected wakeup command!", text)
  if text
    textbox().value += text
    form().submit()
  else
    textbox().focus()

annyang.addCommand just_keyword, callback
annyang.addCommand keyword_and_phrase, callback

annyang.debug()
annyang.start()

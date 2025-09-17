# This is a simple fix for candidates using email adresses unable to send replies to certain other adresses
import strutils, os, rdstdin, strformat
import libclip/clipboard

type
  candidateMail = object
    cand_email: string
    cand_affected: bool

  recruiterMail = object
    rec_email: string
    rec_backup: string
    rec_content: string

func init_cand_mail(candidate_mail_adress: string): candidateMail =
  return candidateMail(cand_email: candidate_mail_adress, cand_affected: candidate_mail_adress.contains("outlook"))

proc yes_or_no(context: string): bool =
  echo $context
  while true:
    let user_input: string = try: readLineFromStdin("y/n\nInput: ") except: ""
    if "y" in user_input:
      result = true
      break
    elif "n" in user_input:
      result = false
      break
    elif user_input == "" or user_input == " ":
      continue
    else:
      echo "Input y to accept or n to reject"
  return result

proc read_config_file(file_name: string): seq[string] =
  if not fileExists(&"settings/{file_name}"):
    let input_manually: bool = yes_or_no(&"Could not find {file_name}, continue manually?")
    if not input_manually:
      result[0] = "quit"
    result[0] = "manual_mode"
    return result
  else:
    let config_list: seq[string] = readFile(&"settings/{filename}").splitLines()
    for config_element in config_list:
      let config_element: string = config_element
      result.add(config_element)
  return result

proc init_recruiter_mail(config_type: string): recruiterMail =
  var 
    rec_mail: recruiterMail
    manual_input: bool = false
  case config_type:
    of "txtFileRuntime":
        let read_results: seq[string] = read_config_file("recruiter_mail_config.txt")
        if len(read_results) > 0:
          var i: int = 0
          for i_item in read_results:
            let i_item: string = i_item
            if i == 0: rec_mail.rec_email = i_item
            else: rec_mail.rec_content.add(&"\n{i_item}")
            inc(i)
        elif read_results[0] == "manual_mode":
          manual_input = true
        else: rec_mail.rec_email = "invalid"
    of "manual_mode": 
      manual_input = true
  if manual_input:
    while true:
      var accepted: bool 
      rec_mail.rec_email = readLineFromStdin("Input backup email adress: ")
      accepted = yes_or_no(fmt"Is this the correct backup email adress? {rec_mail.rec_email}")
      if not accepted: continue
      rec_mail.rec_content = readLineFromStdin("Input email text content: ")
      accepted = yes_or_no(fmt"Is this email text content correct? {rec_mail.rec_content}")
      if not accepted: continue
      break
  return rec_mail

proc wait_for_new_clipboard(clipboard_old: string, sleeptime:int, max_sleep_cycles: int): string =
  var sleep_cycles: int = 0
  while true:
    let clipboard_new: string = getClipboardText()
    if not (clipboard_new == clipboard_old):
      result = clipboard_new
      break
    inc(sleep_cycles)
    if sleep_cycles > max_sleep_cycles:
      if not yes_or_no("Timed out while awaiting new clipboard, continue waiting?"):
        result = "quit"
        break
      sleep_cycles = 0
    sleep(sleeptime)

proc main =
  let 
    sleeptime: int = 1000
    mcfgVals: array[0..1, string] = ["manual_mode", "txtFileRuntime"]

  var 
    init_complete: bool = false
    cur_rec_mail: recruiterMail
    cur_cand_mail: candidateMail
    clipboard_string: string = " "

  while true:
    if not init_complete:
      echo "Welcome to my little program, input a number from the list below to continue!"
      for i in 0 .. 2:
        if i <= 1:
          echo &"{i}: {mcfgVals[i]}"
          continue
        echo &"{i}: quit"
      let choice: string = readLineFromStdin("Input number: ")
      var cfg_option: string
      case choice:
        of "0": 
          cfg_option = "txtFileRuntime"
        of "1": 
          cfg_option = "manual_mode"
        of "2":
          echo "Goodbye!"
          break
      cur_rec_mail = init_recruiter_mail(cfg_option)
      if cur_rec_mail.rec_email == "invalid":
        if yes_or_no("Do you want to quit the program?"): break
        continue
      discard setClipboardText(" ")
      init_complete = true

    echo "To continue, please copy the candidates email adress to your clipboard"
    clipboard_string = wait_for_new_clipboard(clipboard_string, sleeptime, 60)
    if clipboard_string == "quit":
      break

    let cand_mail: candidateMail = init_cand_mail(clipboard_string)
    if not cand_mail.cand_affected:
      echo "No action needed for adress"
      continue
    elif cand_mail.cand_affected:
      discard setClipboardText(&"Replies will only be seen if sent to the following email adress: {cur_rec_mail.rec_email}\n{cur_rec_mail.rec_content}")
      echo "Action taken: added backup email"
      echo "Ready to paste modified clipboard!"
      sleep(5000)

when isMainModule:
  main()
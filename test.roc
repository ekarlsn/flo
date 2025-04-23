app [main!] {
    cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.19.0/Hj-J_zxz7V9YurCSTFcFdu6cQJie4guzsPMUi5kBYUk.tar.br",
    ansi: "https://github.com/lukewilliamboswell/roc-ansi/releases/download/0.8.0/RQlGWlkQEfxtkSYKl0nHNQaOFT0-Jh7NNFEX2IPXlec.tar.br",
}

import cli.Stdout
import cli.Stdin
import cli.File
import Lib

tests = [
    { name: "Test Trim", options: [], actions: [Trim], lines: " abc\ndef " },
    { name: "Test Dup", options: [], actions: [Dup], lines: " abc\ndef " },
]

main! = |_args|
    tests |> List.walk!({}, run_test!)
    Ok({})

run_test! : {}, { name : Str, options : List Lib.Config, actions : List Lib.Action, lines : Str } => {}
run_test! = |_state, { name, options, actions, lines }|
    snapshot_filename = "snapshots/${name}.txt"
    actual_output = Lib.main3({ options, actions, lines })
    when File.read_utf8!(snapshot_filename) is
        Err(_) ->
            # TODO: Assume file not found...
            _ = Stdout.line!("Read utf8 failed")
            _ = File.write_utf8!(actual_output, snapshot_filename)
            {}

        Ok(snapshot_text) ->
            _ = Stdout.line!("Running test: ${name}")
            if actual_output == snapshot_text then
                _ = Stdout.line!("Test passed")
                _ = Stdout.line!("")
                {}
            else
                _ = Stdout.line!("Test failed\n")
                diff_str = "Expected:\n${snapshot_text}\n\nActual:\n${actual_output}"
                accept_update = ask_to_accept!(diff_str)
                when accept_update is
                    Err(_) ->
                        _ = Stdout.line!("Update failed")
                        _ = Stdout.line!("")
                        {}

                    Ok(RejectSnapshot) ->
                        _ = Stdout.line!("No update")
                        _ = Stdout.line!("")
                        {}

                    Ok(AcceptSnapshot) ->
                        _ = File.write_utf8!(actual_output, snapshot_filename)
                        _ = Stdout.line!("Update successful")
                        _ = Stdout.line!("")
                        {}

ask_to_accept! = |text|
    _ = Stdout.line!(text)
    _ = Stdout.line!("\nAccept snapshot update?")
    answer = Stdin.line!({})?
    if answer == "y" or answer == "yes" then
        Ok(AcceptSnapshot)
    else
        Ok(RejectSnapshot)

fut = |_|
    "mmy alue-s-"

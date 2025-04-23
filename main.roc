app [main!] {
    cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.19.0/Hj-J_zxz7V9YurCSTFcFdu6cQJie4guzsPMUi5kBYUk.tar.br",
}

import cli.Stdout
import cli.Stdin
import cli.Arg
import Lib

main! = |raw_args|
    args = List.map(raw_args, Arg.display) |> List.drop_first(1)
    main2!(args)

main2! = |args|
    input_str = read_utf8_input!({})?
    input = Lib.handle_input(input_str, args)
    when input is
        Err(InvalidAction(msg)) -> Err(Exit(1, "Invalid action error: ${msg}"))
        Err(InvalidConfig(msg)) -> Err(Exit(1, "Invalid config error: ${msg}"))
        Err(NoActionProvided) ->
            Stdout.line!(Lib.print_help)

        Err(_) -> Err(Exit(1, "Unhandled error"))
        Ok(valid_input) ->
            line = Lib.main3(valid_input)
            Stdout.line!(line)

read_utf8_input! : {} => Result Str [StdinErr _, BadUtf8 _]
read_utf8_input! = |{}|
    input = Stdin.read_to_end!({})?
    Str.from_utf8(input)

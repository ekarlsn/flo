app [main!] {
    cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.19.0/Hj-J_zxz7V9YurCSTFcFdu6cQJie4guzsPMUi5kBYUk.tar.br",
}

import cli.Stdout
import cli.Stdin
import cli.Arg

main! = |raw_args|
    args = List.map(raw_args, Arg.display) |> List.drop_first(1)
    when handle_input!(args) is
        Err(InvalidAction(msg)) -> Err(Exit(1, "Invalid action error: $(msg)"))
        Err(InvalidConfig(msg)) -> Err(Exit(1, "Invalid config error: $(msg)"))
        Err(_) -> Err(Exit(1, "Unhandled error"))
        Ok({options, actions, lines}) ->
            dbg options
            {input, transformations} = List.walk_try(actions, { input: lines, transformations: [] }, |state, action|
                output = state.input |> apply_action(action)
                Ok({
                    input: output,
                    transformations: state.transformations |> List.append(output)
                }))?

            output_text_blocks = List.map(transformations, |trans| Str.join_with(trans, "\n"))
            action_and_text = List.map2(actions, output_text_blocks, |action, text|
                action_text = action_to_text(action)
                "$(action_text):\n$(text)"
            )
            input_text_block = Str.join_with(lines, "\n")
            output_text = Str.join_with(action_and_text, "\n\nThen: ")

            if List.any(options, |o| o == StepDebug) then
                Stdout.line!("Input:\n$(input_text_block)\n\nThen: ${output_text}")
            else
                last_output = List.last(transformations) |> Result.map_ok(|ok_lines| Str.join_with(ok_lines, "\n"))
                when last_output is
                    Ok(text) ->
                        Stdout.line!(text)
                    Err(_) ->
                        Stdout.line!("")

action_to_text : Action -> Str
action_to_text = |action| Inspect.to_str(action)

apply_action : List Str, Action -> List Str
apply_action = |lines, action|
    when action is
        KeepRows index ->
            apply_action_keeprows(index, lines)
        Dup ->
            apply_action_dup(lines)
        Col _ -> lines
        Trim ->
            apply_action_trim(lines)
        StripRight str ->
            apply_action_strip_right(str, lines)
        StripLeft str ->
            apply_action_strip_left(str, lines)
        ColAppend str ->
            apply_action_col_append(str, lines)
        ColPrepend str ->
            apply_action_col_prepend(str, lines)

        Sort ->
            apply_action_sort(lines)

apply_action_col_append : Str, List Str -> List Str
apply_action_col_append = |append_str, lines|
    lines |> List.map(|line| Str.concat(line, append_str))

apply_action_col_prepend : Str, List Str -> List Str
apply_action_col_prepend = |prepend_str, lines|
    lines |> List.map(|line| Str.concat(prepend_str, line))

apply_action_trim : List Str -> List Str
apply_action_trim = |lines|
    lines |> List.map(Str.trim)

apply_action_sort : List Str -> List Str
apply_action_sort = |lines|
    # TODO
    lines



apply_action_strip_right : Str, List Str -> List Str
apply_action_strip_right = |strip_str, lines|
    lines |> List.map(|line|
        if Str.ends_with(line, strip_str) then
            Str.replace_last(line, strip_str, "")
        else
            line
    )

apply_action_strip_left : Str, List Str -> List Str
apply_action_strip_left = |strip_str, lines|
        lines |> List.map(|line|
            if Str.starts_with(line, strip_str) then
                Str.replace_first(line, strip_str, "")
            else
                line
        )

apply_action_dup : List Str -> List Str
apply_action_dup = |lines|
    lines |> List.map(|line| [line, line] |> Str.join_with(" "))

apply_action_keeprows : PythonListIndex, List Str -> List Str
apply_action_keeprows = |{start, end}, lines|
    line_count : U32
    line_count = lines |> List.len |> Num.int_cast
    dbg end
    start_index = when start is
        Start -> 0
        FromLeft(num) -> num |> Num.min (line_count)
        FromRight(num) ->
            Num.sub_saturated(line_count, num)
    end_index = when end is
        End -> line_count - 1
        FromLeft(num) -> num |> Num.min (line_count)
        FromRight(num) -> Num.sub_saturated(line_count, num)
    dbg start_index
    dbg end_index
    lines |> List.sublist({start: start_index |> Num.int_cast, len: end_index - start_index  |> Num.int_cast})

handle_input! : List Str => Result {options: List Config, actions: List Action, lines: List Str} [StdinErr _, BadUtf8 _, InvalidAction Str, InvalidConfig Str]
handle_input! = |args|
    when parse_args(args) is
        Err(InvalidAction(err)) -> Err(InvalidAction(err))
        Err(InvalidConfig(err)) -> Err(InvalidConfig(err))
        Ok({actions, options}) ->
            dbg options
            input_str = read_utf8_input!({})?
            lines = Str.split_on(input_str, "\n")
            Ok({options, actions, lines})

read_utf8_input! : {} => Result Str [StdinErr _, BadUtf8 _]
read_utf8_input! = |{}|
    input = Stdin.read_to_end!({})?
    Str.from_utf8(input)

Config : [StepDebug]

parse_args : List Str  -> Result ({actions: List Action, options: List Config}) [InvalidAction Str, InvalidConfig Str]
parse_args = |args|
    parsed_args = args |> List.split_on("-") |> dbg
    {config_args, action_args} = when parsed_args is
        [[e, ..] as config_arg_list, ..] if Str.starts_with(e, "--") ->
            config_args_ = parse_config_args(config_arg_list)?
            dbg config_args_
            {config_args: config_args_, action_args: parsed_args |> List.drop_first 1}
        _ -> {config_args: [], action_args: parsed_args}

    maybe_actions = action_args |> List.map(parse_action) |> to_one_action_error
    actions = maybe_actions |> Result.map_err(|e| when e is
        InvalidAction msg ->
            InvalidAction msg
        _ ->
            InvalidConfig "never"
    )?
    Ok({actions: actions, options: config_args})

parse_config_args : List Str -> Result (List Config) [InvalidConfig Str]
parse_config_args = |args_str|
    Ok([StepDebug])

get_head : List a -> Result {head: a, tail: List a} [ListWasEmpty]
get_head = |list|
    when list is
        [] -> Err(ListWasEmpty)
        [head, .. as tail] -> Ok({head, tail})


to_one_action_error : List [ Ok Action, Err ([InvalidAction Str]) ] -> Result (List Action) [InvalidAction Str]
to_one_action_error = |actions|
        all_errors = actions |> List.keep_errs(|action| action)
        first_error = all_errors |> List.first
        when first_error is
            Err(ListWasEmpty) ->
                dbg actions
                actions |> List.keep_oks(|action| action) |> Ok
            Ok(err) -> Err(err)

Action : [ KeepRows PythonListIndex, Col {num: U32}, Dup, StripRight Str, StripLeft Str, ColAppend Str, ColPrepend Str, Trim, Sort ]

PythonListIndex : { start: [Start, FromLeft U32, FromRight U32], end: [End, FromLeft U32, FromRight U32] }

parse_action : List Str -> Result Action [InvalidAction Str]
parse_action = |args|
    keyword = args |> List.first |> Result.map_err(|_| InvalidAction "Empty")?
    kw_args = args |> List.drop_first 1
    when keyword is
        "keep-rows" -> when kw_args |> List.first is
                Err(_) -> Err(InvalidAction("Expected exactly one argument for keep-rows"))
                Ok(python_list_index) -> parse_python_list_index(python_list_index) |> Result.map_ok(|index| KeepRows index)
        "col" -> Ok(Col { num: 1 })
        "dup" -> Ok(Dup)
        "trim" -> Ok(Trim)
        "sort" -> Ok(Sort)
        "strip-left" ->
            when kw_args |> List.first is
                Err(_) -> Err(InvalidAction("Expected exactly one argument for strip-left"))
                Ok(strip_str) -> Ok(StripLeft strip_str)
        "strip-right" ->
            when kw_args |> List.first is
                Err(_) -> Err(InvalidAction("Expected exactly one argument for strip-right"))
                Ok(strip_str) -> Ok(StripRight strip_str)
        "col-append" ->
            when kw_args |> List.first is
                Err(_) -> Err(InvalidAction("Expected exactly one argument for col-append"))
                Ok(append_str) -> Ok(ColAppend append_str)
        "col-prepend" ->
            when kw_args |> List.first is
                Err(_) -> Err(InvalidAction("Expected exactly one argument for col-prepend"))
                Ok(prepend_str) -> Ok(ColPrepend prepend_str)
        _ -> Err(InvalidAction("Unknown action \"$(keyword)\""))

parse_python_list_index : Str -> Result PythonListIndex [InvalidAction Str]
parse_python_list_index = |input|
    parts = input |> Str.split_on(":")
    when parts is
        [start, ""] ->
            int_start = Str.to_u32(start) |> Result.map_err(|_| InvalidAction("Invalid start index \"$(start)\""))?
            { start: FromLeft int_start, end: End } |> Ok
        ["", end] ->
            int_end = Str.to_u32(end) |> Result.map_err(|_| InvalidAction("Invalid end index \"$(end)\""))?
            { start: Start, end: FromLeft int_end } |> Ok
        [start, end] ->
            Err(InvalidAction("List index start:end not supported yet"))
        [index] ->
            int_start = Str.to_u32(index) |> Result.map_err(|_| InvalidAction("Invalid index \"$(index)\""))?
            { start: FromLeft int_start, end: FromLeft int_start } |> Ok
        _ -> Err(InvalidAction("Unknown index format \"$(input)\""))

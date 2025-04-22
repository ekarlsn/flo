app [main!] {
    cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.19.0/Hj-J_zxz7V9YurCSTFcFdu6cQJie4guzsPMUi5kBYUk.tar.br",
}

import cli.Stdout
import cli.Stdin
import cli.Arg

main! = |raw_args|
    args = List.map(raw_args, Arg.display) |> List.drop_first(1)
    when handle_input!(args) is
        Err(InvalidAction(msg)) -> Err(Exit(1, "Invalid action error: ${msg}"))
        Err(InvalidConfig(msg)) -> Err(Exit(1, "Invalid config error: ${msg}"))
        Err(_) -> Err(Exit(1, "Unhandled error"))
        Ok({ options, actions, lines }) ->
            if List.any(options, |o| o == PrintHelp) then
                print_help!({})
            else
                dbg options
                { input, transformations } = List.walk_try(
                    actions,
                    { input: lines, transformations: [] },
                    |state, action|
                        output = state.input |> apply_action(action)
                        Ok(
                            {
                                input: output,
                                transformations: state.transformations |> List.append(output),
                            },
                        ),
                )?

                output_text_blocks = List.map(transformations, |trans| Str.join_with(trans, "\n"))
                action_and_text = List.map2(
                    actions,
                    output_text_blocks,
                    |action, text|
                        action_text = action_to_text(action)
                        "${action_text}:\n${text}",
                )
                input_text_block = Str.join_with(lines, "\n")
                output_text = Str.join_with(action_and_text, "\n\nThen: ")

                if List.any(options, |o| o == StepDebug) then
                    Stdout.line!("Input:\n${input_text_block}\n\nThen: ${output_text}")
                else
                    last_output = List.last(transformations) |> Result.map_ok(|ok_lines| Str.join_with(ok_lines, "\n"))
                    when last_output is
                        Ok(text) ->
                            Stdout.line!(text)

                        Err(_) ->
                            Stdout.line!("")

print_help! : {} => _
print_help! = |{}|
    help_text =
        available_actions
        |> List.map(
            |a|
                name = a.name
                help = a.help
                "${name}\n    ${help}",
        )
        |> Str.join_with("\n\n")

    Stdout.line!("Help!\n\nAvailable actions:\n\n${help_text}")

action_to_text : Action -> Str
action_to_text = |action| Inspect.to_str(action)

apply_action : List Str, Action -> List Str
apply_action = |lines, action|
    when action is
        KeepRows index ->
            apply_action_keeprows(index, lines)

        KeepCols index ->
            apply_action_keepcols(index, lines)

        Dup ->
            apply_action_dup(lines)

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

        Uniq ->
            apply_action_uniq(lines)

        Split s ->
            apply_action_split(lines, s)

        Grep s ->
            apply_action_grep(lines, s)

apply_action_grep : List Str, Str -> List Str
apply_action_grep = |lines, grep_str|
    lines
    |> List.keep_if(|e| e |> Str.contains grep_str)

apply_action_split : List Str, Str -> List Str
apply_action_split = |lines, split_str|
    lines
    |> List.map(
        |line|
            line
            |> Str.split_on(split_str),
    )
    |> List.join

apply_action_col_append : Str, List Str -> List Str
apply_action_col_append = |append_str, lines|
    lines |> List.map(|line| Str.concat(line, append_str))

apply_action_col_prepend : Str, List Str -> List Str
apply_action_col_prepend = |prepend_str, lines|
    lines |> List.map(|line| Str.concat(prepend_str, line))

apply_action_trim : List Str -> List Str
apply_action_trim = |lines|
    lines |> List.map(Str.trim)

apply_action_uniq : List Str -> List Str
apply_action_uniq = |lines|
    lines
    |>
    List.walk([], uniq_helper)

uniq_helper : List Str, Str -> List Str
uniq_helper = |l, e|
    when l is
        [.., last] ->
            if last == e then
                l
            else
                List.append(l, e)

        [] -> [e]

apply_action_sort : List Str -> List Str
apply_action_sort = |lines|
    lines |> List.sort_with(string_compare)

string_compare : Str, Str -> [EQ, LT, GT]
string_compare = |a, b|
    aBytes = a |> Str.to_utf8
    bBytes = b |> Str.to_utf8

    result1 =
        List.map2(aBytes, bBytes, Pair)
        |> List.walk_until(EQ, |state, Pair aa bb| if aa > bb then Break GT else if bb > aa then Break LT else Continue EQ)

    if result1 == EQ then
        if List.len aBytes > List.len bBytes then
            GT
        else if List.len aBytes < List.len bBytes then
            LT
        else
            EQ
    else
        result1

expect string_compare("a", "b") == LT
expect string_compare("b", "a") == GT
expect string_compare("a", "a") == EQ

apply_action_strip_right : Str, List Str -> List Str
apply_action_strip_right = |strip_str, lines|
    lines
    |> List.map(
        |line|
            if Str.ends_with(line, strip_str) then
                Str.replace_last(line, strip_str, "")
            else
                line,
    )

apply_action_strip_left : Str, List Str -> List Str
apply_action_strip_left = |strip_str, lines|
    lines
    |> List.map(
        |line|
            if Str.starts_with(line, strip_str) then
                Str.replace_first(line, strip_str, "")
            else
                line,
    )

apply_action_dup : List Str -> List Str
apply_action_dup = |lines|
    lines |> List.map(|line| [line, line] |> Str.join_with(" "))

apply_action_keepcols : PythonListIndex, List Str -> List Str
apply_action_keepcols = |index, lines|
    lines
    |> List.map(
        |row|
            cols = row |> Str.split_on(" ") |> List.keep_if(|e| e |> Str.is_empty |> Bool.not)
            apply_action_keeprows index cols |> Str.join_with(" "),
    )

apply_action_keeprows : PythonListIndex, List Str -> List Str
apply_action_keeprows = |{ start, end }, lines|
    line_count : U32
    line_count = lines |> List.len |> Num.int_cast
    dbg end
    start_index =
        when start is
            Start -> 0
            FromLeft(num) -> num |> Num.min (line_count)
            FromRight(num) ->
                Num.sub_saturated(line_count, num)
    end_index =
        when end is
            End -> line_count - 1
            FromLeft(num) -> num |> Num.min (line_count)
            FromRight(num) -> Num.sub_saturated(line_count, num)
    dbg start_index
    dbg end_index
    lines |> List.sublist({ start: start_index |> Num.int_cast, len: end_index - start_index |> Num.int_cast })

handle_input! : List Str => Result { options : List Config, actions : List Action, lines : List Str } [StdinErr _, BadUtf8 _, InvalidAction Str, InvalidConfig Str]
handle_input! = |args|
    when parse_args(args) is
        Err(InvalidAction(err)) -> Err(InvalidAction(err))
        Err(InvalidConfig(err)) -> Err(InvalidConfig(err))
        Ok({ actions, options }) ->
            dbg options
            input_str = read_utf8_input!({})?
            lines = Str.split_on(input_str, "\n")
            Ok({ options, actions, lines })

read_utf8_input! : {} => Result Str [StdinErr _, BadUtf8 _]
read_utf8_input! = |{}|
    input = Stdin.read_to_end!({})?
    Str.from_utf8(input)

Config : [StepDebug, PrintHelp]

parse_args : List Str -> Result { actions : List Action, options : List Config } [InvalidAction Str, InvalidConfig Str]
parse_args = |args|
    parsed_args = args |> List.split_on("-") |> dbg
    { config_args, action_args } =
        when parsed_args is
            [[e, ..] as config_arg_list, ..] if Str.starts_with(e, "--") ->
                config_args_ = parse_config_args(config_arg_list) |> Result.map_err(|InvalidConfig err| InvalidConfig err)?
                dbg config_args_
                { config_args: config_args_, action_args: parsed_args |> List.drop_first 1 }

            _ -> { config_args: [], action_args: parsed_args }

    maybe_actions = action_args |> List.map(parse_action) |> to_one_action_error
    actions = maybe_actions |> Result.map_err(|InvalidAction e| InvalidAction e)?
    Ok({ actions: actions, options: config_args })

parse_config_args : List Str -> Result (List Config) [InvalidConfig Str]
parse_config_args = |args_str|
    when args_str is
        ["--debug", .. as rest] ->
            (parse_config_args rest)?
            |> List.append StepDebug
            |> Ok

        ["--help", .. as rest] ->
            (parse_config_args rest)?
            |> List.append PrintHelp
            |> Ok

        [other, ..] ->
            Err(InvalidConfig "Unknown command line option ${other}")

        [] ->
            Ok([])

get_head : List a -> Result { head : a, tail : List a } [ListWasEmpty]
get_head = |list|
    when list is
        [] -> Err(ListWasEmpty)
        [head, .. as tail] -> Ok({ head, tail })

to_one_action_error : List [Ok Action, Err [InvalidAction Str]] -> Result (List Action) [InvalidAction Str]
to_one_action_error = |actions|
    all_errors = actions |> List.keep_errs(|action| action)
    first_error = all_errors |> List.first
    when first_error is
        Err(ListWasEmpty) ->
            dbg actions
            actions |> List.keep_oks(|action| action) |> Ok

        Ok(err) -> Err(err)

Action : [
    KeepRows PythonListIndex,
    KeepCols PythonListIndex,
    Dup,
    StripRight Str,
    StripLeft Str,
    ColAppend Str,
    ColPrepend Str,
    Trim,
    Sort,
    Uniq,
    Split Str,
    Grep Str,
]

PythonListIndex : { start : [Start, FromLeft U32, FromRight U32], end : [End, FromLeft U32, FromRight U32] }

AvailableAction : { name : Str, help : Str, parse_args : List Str -> Result Action [InvalidAction Str] }

available_actions : List AvailableAction
available_actions = [
    {
        name: "keep-rows",
        help: "Keeps rows, like 'keep-rows 5' filter to show only row 5, or 'keep-rows 5:10' keeps rows 5-10",
        parse_args: parse_keep_rows,
    },
    {
        name: "dup",
        help: "Duplicate rows",
        parse_args: |_| Ok(Dup),
    },
    {
        name: "keep-cols",
        help: "Keep columns, see keep-rows for details",
        parse_args: action_parser1(parse_python_list_index, KeepCols),
    },
    { name: "trim", help: "Remove whitespace to the left and right of each row", parse_args: |_| Ok(Trim) },
    { name: "sort", help: "Sort the rows in the list", parse_args: |_| Ok(Sort) },
    { name: "uniq", help: "Remove every duplicate consecutive item in the list", parse_args: |_| Ok(Uniq) },
    {
        name: "split",
        help: "split <str>: For a row, split it on <str>, replacing each occurance with a space",
        parse_args: action_parser1(Ok, Split),
    },
    {
        name: "grep",
        help: "grep <filter>: Filter rows and include only those that include the literal <filter>",
        parse_args: action_parser1(Ok, Grep),
    },
    {
        name: "strip-left",
        help: "strip-left <str>: Remove exactly <str> from the left of each row, if it's not present, nothing will be removed",
        parse_args: action_parser1(Ok, StripLeft),
    },
    {
        name: "strip-right",
        help: "strip-right <str>: See strip-left",
        parse_args: action_parser1(Ok, StripRight),
    },
    {
        name: "col-append",
        help: "col-append <str>: Append <str> at the end of every row",
        parse_args: action_parser1(Ok, ColAppend),
    },
    {
        name: "col-prepend",
        help: "col-prepend <str>: Like col-append, but at the start of the row",
        parse_args: action_parser1(Ok, ColPrepend),
    },
]

action_parser1 : (Str -> Result a [InvalidAction Str]), (a -> Action) -> (List Str -> Result Action [InvalidAction Str])
action_parser1 = |arg_transform, make_action|
    |kw_args|
        when kw_args |> List.first is
            Err(_) -> Err(InvalidAction("Expected exactly one argument for keep-cols"))
            Ok(python_list_index) -> arg_transform(python_list_index) |> Result.map_ok(|index| make_action(index))

parse_keep_rows : List Str -> Result Action [InvalidAction Str]
parse_keep_rows = |args|
    when args |> List.first is
        Err(_) -> Err(InvalidAction("Expected exactly one argument for keep-rows"))
        Ok(python_list_index) -> parse_python_list_index(python_list_index) |> Result.map_ok(|index| KeepRows index)

parse_action : List Str -> Result Action [InvalidAction Str]
parse_action = |args|
    keyword = args |> List.first |> Result.map_err(|_| InvalidAction "Empty")?
    kw_args = args |> List.drop_first 1
    action_info =
        available_actions
        |> List.find_first(|e| e.name == keyword)
        |> Result.map_err(|_| InvalidAction "Unknown action \"${keyword}\"")?
    action_info.parse_args(kw_args)

parse_python_list_index : Str -> Result PythonListIndex [InvalidAction Str]
parse_python_list_index = |input|
    parts = input |> Str.split_on(":")
    when parts is
        [start, ""] ->
            int_start = Str.to_u32(start) |> Result.map_err(|_| InvalidAction("Invalid start index \"${start}\""))?
            { start: FromLeft int_start, end: End } |> Ok

        ["", end] ->
            int_end = Str.to_u32(end) |> Result.map_err(|_| InvalidAction("Invalid end index \"${end}\""))?
            { start: Start, end: FromLeft int_end } |> Ok

        [start, end] ->
            int_start = Str.to_u32(start) |> Result.map_err(|_| InvalidAction("Invalid index \"${start}\""))?
            int_end = Str.to_u32(end) |> Result.map_err(|_| InvalidAction("Invalid end index \"${end}\""))?
            { start: FromLeft int_start, end: FromLeft int_end } |> Ok

        [index] ->
            int_start = Str.to_u32(index) |> Result.map_err(|_| InvalidAction("Invalid index \"${index}\""))?
            { start: FromLeft int_start, end: FromLeft (int_start + 1) } |> Ok

        _ -> Err(InvalidAction("Unknown index format \"${input}\""))

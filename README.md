# Flo

A compact CLI tool for text transformations, making complex operations intuitive.

## Status

Very much a work in progress. Expect frequent changes and breaking changes. Expected unexpected behavior.

## Install

```bash
git clone https://github.com/yourusername/flo.git
cd flo && roc build
```

## Usage

```
cat input.txt | flo [options -] action1 arg1 - action2 arg2 ...
```

Options: `--help`, `--debug`

## Why flo?

Flo simplifies complex text transformations that would otherwise require multiple commands:

### Example 1: Extract and process the second column from CSV

**Without flo:**
```bash
cat data.csv | cut -d',' -f2 | sed 's/^ *//' | sed 's/ *$//' | sort | uniq
```

**With flo:**
```bash
cat data.csv | flo split "," - keep-cols 1 - trim - sort - uniq
```

### Example 2: Extract error logs with timestamps

**Without flo:**
```bash
grep "ERROR" logs.txt | sed 's/^.*\[//' | sed 's/\].*$//' | sort
```

**With flo:**
```bash
cat logs.txt | flo grep "ERROR" - strip-left "[" - strip-right "]" - sort
```

### Example 3: Format a list of items

**Without flo:**
```bash
cat items.txt | sort | uniq | sed 's/^/- /'
```

**With flo:**
```bash
cat items.txt | flo sort - uniq - col-prepend "- "
```

## Actions

- **keep-rows** `N` or `start:end`: Keep specific rows
- **keep-cols** `N` or `start:end`: Keep specific columns
- **dup**: Duplicate each line
- **trim**: Remove whitespace from line ends
- **strip-left/right** `str`: Remove specified string from start/end
- **col-append/prepend** `str`: Add text to end/start of each line
- **sort**: Sort lines alphabetically
- **uniq**: Remove consecutive duplicates
- **split** `delimiter`: Split lines on delimiter
- **grep** `pattern`: Filter lines containing pattern

## Debug Mode

See transformation steps:

```bash
echo "a,b,c" | flo --debug split "," - trim
echo "   a,b,c" | flo --debug - split "," - trim
```

Output:
```
Input:
   a,b,c


Then: (Split ","):
   a
b
c


Then: Trim:
a
b
c
```

# Bake

Bake: A Bash-based Make alternative

## Overview

Bake is a dead-simple task runner used to quickly cobble together shell scripts

In a few words, Bake lets you call the following 'print' task with './bake print'

```bash
#!/usr/bin/env bash
task.print() {
printf '%s\n' 'Contrived example'
}
```

Learn more about it [on GitHub](https://github.com/hyperupcall/bake)

## Index

* [die()](#die)
* [error()](#error)
* [warn()](#warn)
* [info()](#info)

### die()

Prints '$1' to the console as an error, then exits with code 1

### error()

Prints '$1' formatted as an error to standard error

### warn()

Prints '$1' formatted as a warning to standard error

### info()

Prints '$1' formatted as information to standard output

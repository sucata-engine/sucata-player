package main

import cli "./src/cli"
import core "./src/core"
import "base:runtime"
import "core:log"

main :: proc() {
	context.logger = log.create_console_logger()
	core.DEFAULT_CONTEXT = context
	core.init_temp_arena()

	cli.main()
}

// Investigar todos filepath, provavelmente estao com memory leak
// Arrumar shader para ser um i32 inves de um texto

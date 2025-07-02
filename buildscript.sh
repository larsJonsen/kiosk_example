#!/bin/bash
export MIX_ENV=prod
export MIX_TARGET=rpi4
export ERL_COMPILER_OPTIONS="[{d,'SKIP_NIF_LOADING'}]"

mix clean
mix deps.clean --build
mix deps.get
mix compile
mix firmware
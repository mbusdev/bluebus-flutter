#!/bin/bash

rm -r lib/backend || true
dart run build_runner clean
dart run swagger_parser
dart run build_runner build

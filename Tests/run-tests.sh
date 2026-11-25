#!/usr/bin/env sh
set -eu

lake build
lake env lean Tests/AnalysisTest.lean
lake env lean Tests/Fixture.lean

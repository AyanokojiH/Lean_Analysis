$ErrorActionPreference = "Stop"

lake build
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

lake env lean Tests\AnalysisTest.lean
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

lake env lean Tests\Fixture.lean
exit $LASTEXITCODE

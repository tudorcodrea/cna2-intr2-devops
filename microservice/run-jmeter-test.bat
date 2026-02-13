@echo off
REM Claims Service JMeter Load Test Runner
REM Usage: run-jmeter-test.bat [claims_per_minute] [duration_minutes]

if "%~1"=="" (
    set CLAIMS_PER_MINUTE=100
) else (
    set CLAIMS_PER_MINUTE=%~1
)

if "%~2"=="" (
    set TEST_DURATION_MINUTES=5
) else (
    set TEST_DURATION_MINUTES=%~2
)

echo Running Claims Service Load Test
echo Target: %CLAIMS_PER_MINUTE% claims per minute
echo Duration: %TEST_DURATION_MINUTES% minutes
echo.

REM Check if JMeter is installed
jmeter --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: JMeter is not installed or not in PATH
    echo Please install JMeter and add it to your PATH
    pause
    exit /b 1
)

REM Create results directory
if not exist "jmeter-results" mkdir jmeter-results

REM Run the test
echo Starting JMeter test...
jmeter -n -t claims-service-load-test.jmx ^
    -l jmeter-results\test-results.jtl ^
    -j jmeter-results\jmeter.log ^
    -JCLAIMS_PER_MINUTE=%CLAIMS_PER_MINUTE% ^
    -JTEST_DURATION_MINUTES=%TEST_DURATION_MINUTES%

echo.
echo Test completed. Results saved in jmeter-results\ directory
echo - Raw results: test-results.jtl
echo - JMeter log: jmeter.log
echo.
echo To view results in JMeter GUI:
echo jmeter -t claims-service-load-test.jmx -l jmeter-results\test-results.jtl
echo.
pause
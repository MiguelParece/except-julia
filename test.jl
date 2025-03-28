import Main.Exceptional: error, handling, with_restart, invoke_restart, available_restart, to_escape
import Main.Exceptional: DivisionByZero, EndOfLine
using Test
include("Exceptional.jl")

# Reciprocal function with restarts
function reciprocal(value)
    with_restart(
        :return_zero => () -> 0,
        :return_value => identity,
        :retry_using => reciprocal
    ) do
        value == 0 ? Exceptional.error(DivisionByZero) : 1/value
    end
end

# Test suite
function run_tests()
    @testset "Exceptional Module Tests" begin
        @testset "Basic Restart Functionality" begin
            # Normal computation
            @test reciprocal(10) == 0.1

            # Test return_zero restart
            @test begin
                handling(DivisionByZero => (c) -> invoke_restart(:return_zero)) do
                    reciprocal(0)
                end == 0
            end

            # Test return_value restart
            @test begin
                handling(DivisionByZero => (c) -> invoke_restart(:return_value, 123)) do
                    reciprocal(0)
                end == 123
            end

            # Test retry_using restart
            @test begin
                handling(DivisionByZero => (c) -> invoke_restart(:retry_using, 10)) do
                    reciprocal(0)
                end == 0.1
            end
        end

    end

    @testset "Available Restart Tests" begin
        @test begin
            handling(DivisionByZero => (c) -> begin
                restarts = [:lifint, :return_value, :die]
                any(available_restart(restart) for restart in restarts)
            end) do
                reciprocal(0)
            end == true
        end
    end

    @testset "To Escape Functionality" begin
        @test begin
            to_escape() do exit
                exit(42)
            end == 42
        end

        @test begin
            to_escape() do exit
                handling(DivisionByZero => (c) -> exit("Handled")) do
                    reciprocal(0)
                end
            end == "Handled"
        end
    end

    @testset "Nested Restart Propagation" begin
        # Nested function to test restart propagation
        function infinity()
            with_restart(:just_do_it => () -> 1/0
                         ) do
                reciprocal(0)
            end
        end

        @test begin
            handling(DivisionByZero => (c) -> invoke_restart(:return_zero)) do
                infinity()
            end == 0
        end

        @test begin
            handling(DivisionByZero => (c) -> invoke_restart(:return_value, 1)) do
                infinity()
            end == 1
        end

        @test begin
            handling(DivisionByZero => (c) -> invoke_restart(:retry_using,10)) do
                infinity()
            end == 0.1
        end

        @test begin
            handling(DivisionByZero => (c) -> invoke_restart(:just_do_it)) do
                infinity()
            end == Inf
        end
    end
end

# Uncomment the following line to run tests automatically when the file is loaded
run_tests()

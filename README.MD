# Exceptional.jl & ExceptionalExtend.jl

[![Julia 1.10](https://img.shields.io/badge/Julia-1.10-9558B2)](https://julialang.org/)

A Julia implementation of Common Lisp-inspired **exception handling with restarts**, enabling flexible error recovery and interactive debugging.

---

## Features

### Core (`Exceptional.jl`)
- **Dynamic Handlers & Restarts**:  
  - `handling(func, handlers...)`: Bind handlers to exceptions within a scope.  
  - `with_restart(func, restarts...)`: Define restarts (recovery actions) for exceptions.  
  - `signal(exception)`: Non-fatal error signaling.  
  - `error(exception)`: Fatal error signaling (requires handling).  
- **Scoped Control Flow**:  
  - `to_escape(func)`: Create non-local exits (similar to Common Lisp `block`).  
- **Task-Local Storage**:  
  - Handlers and restarts are stored in nested lists for dynamic scoping.  

### Extended (`ExceptionalExtend.jl`)
- **Interactive Restarts**:  
  - `restart_data` struct with metadata (`test`, `report`, `interactive`).  
  - User prompts for restart selection (e.g., `reciprocal(0)` asks for input).  
- **Default Restarts**:  
  - `:abort` (exit) and `:retry` (re-run function).  
- **Backward Compatibility**:  
  - Extended functions retain original behavior while adding new features.  

---

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/exceptional-jl.git
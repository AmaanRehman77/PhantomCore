# Out-of-Order Core with Explicit Register Renaming

This project involves the design and implementation of a **high-performance out-of-order execution core**, leveraging explicit register renaming for optimized resource utilization and reduced data hazards. The core features an advanced instruction scheduling mechanism, dynamic register allocation, and a robust pipeline structure to maximize instruction throughput and minimize stalls.

## Key Features

- **Explicit Register Renaming**:  
  Decouples architectural registers from physical registers to eliminate write-after-write (WAW) and write-after-read (WAR) hazards.

- **Dynamic Scheduling**:  
  Utilizes reservation stations and a reorder buffer to ensure efficient out-of-order execution and precise exception handling.

- **Performance Counters**:  
  Integrated performance counters for profiling and optimization during runtime.

- **Customizable Pipeline Depth**:  
  Adaptable pipeline stages to suit varying workloads and power-performance requirements.

## Applications

This core is designed for applications requiring **high performance and efficiency**, such as:
- Data-intensive computations
- Real-time analytics
- Embedded systems

## Future Work

Future iterations aim to integrate this core into a **multi-core environment** for enhanced scalability and workload balancing.

---

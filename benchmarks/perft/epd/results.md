# Extensive Perft Results

Below you will find results from running the extensive perft suite tracked over various versions of the water library. The tests are all ran on a reasonable rig with an AMD Ryzen 7 7800X3D 8-Core Processor. A successful test should yield 49,548 total passed cases, exploring 4,897,297,259,721 total nodes.

## Data

| Version | Total Cases | Total Passed | Total Failed | Total Nodes       | Total Elapsed (s) | Average NPS    |
|:--------|:------------|:-------------|:-------------|:------------------|:------------------|:---------------|
| v1      | 49,548      | 49,548       | 0            | 4,897,297,259,721 | 17,562            | 278,857,605.04 |

_Note: The nps values calculated above are not a 100% accurate representation of the library's performance. They are simply determined by taking the total explored nodes over the total execution time, which includes file input parsing, I/O operations, allocations, and more. Thus, each reported value is more of an indication of average performance. Structured benchmarks can be seen in a folder of the same name._ 
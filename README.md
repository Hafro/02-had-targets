You can then use R studio within your project or change to the `02-had-targets` directory and load R.

You may see:

```
- One or more packages recorded in the lockfile are not installed.
- Use `renv::status()` for more details.
```

...in which case use renv to restore packages:

```r
renv::restore()
```

Then you can build the advice with the `run.R` script.

The [ROracle](https://cran.r-project.org/package=ROracle) package will not be installed by default, add it with:

```r
install.packages("ROracle")
```

## Development

### Code formatting

This projects uses [Air](https://posit-dev.github.io/air/), you may need to configure your editor accordingly.
See https://posit-dev.github.io/air/editors.html

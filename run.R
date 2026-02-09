Sys.setenv(TAR_PROJECT = "assessment_model")
targets::tar_make()

Sys.setenv(TAR_PROJECT = "plots_and_tables")
targets::tar_make()

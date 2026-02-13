Sys.setenv(TAR_PROJECT = "assessment_model")
targets::tar_make()

Sys.setenv(TAR_PROJECT = "techreport")
targets::tar_make()

Sys.setenv(TAR_PROJECT = "advice")
targets::tar_make()

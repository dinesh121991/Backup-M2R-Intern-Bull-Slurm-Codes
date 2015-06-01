AUTOMAKE_OPTIONS = foreign

PLUGIN_FLAGS = -module -avoid-version --export-dynamic

INCLUDES = -I$(top_srcdir) -I$(top_srcdir)/src/common

pkglib_LTLIBRARIES = layouts_cons_res_partition_default.la

layouts_cons_res_partition_default_la_SOURCES = default.c
layouts_cons_res_partition_default_la_LDFLAGS = $(SO_LDFLAGS) $(PLUGIN_FLAGS)

# Makefile for select/cons_res_layout plugin

AUTOMAKE_OPTIONS = foreign

PLUGIN_FLAGS = -module -avoid-version --export-dynamic

AM_CPPFLAGS = -I$(top_srcdir) -I$(top_srcdir)/src/common

pkglib_LTLIBRARIES = select_cons_res_layout.la

# Consumable resources node selection plugin.
select_cons_res_layout_la_SOURCES =  select_cons_res_layout.c select_cons_res_layout.h \
                              dist_tasks.c dist_tasks.h \
			      job_test.c job_test.h
select_cons_res_layout_la_LDFLAGS = $(SO_LDFLAGS) $(PLUGIN_FLAGS)

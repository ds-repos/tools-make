#
#   application.make
#
#   Makefile rules to build GNUstep-based applications.
#
#   Copyright (C) 1997, 2001 Free Software Foundation, Inc.
#
#   Author:  Nicola Pero <nicola@brainstorm.co.uk>
#   Author:  Ovidiu Predescu <ovidiu@net-community.com>
#   Based on the original version by Scott Christley.
#
#   This file is part of the GNUstep Makefile Package.
#
#   This library is free software; you can redistribute it and/or
#   modify it under the terms of the GNU General Public License
#   as published by the Free Software Foundation; either version 2
#   of the License, or (at your option) any later version.
#   
#   You should have received a copy of the GNU General Public
#   License along with this library; see the file COPYING.LIB.
#   If not, write to the Free Software Foundation,
#   59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

# prevent multiple inclusions
ifeq ($(APPLICATION_MAKE_LOADED),)
APPLICATION_MAKE_LOADED=yes

#
# Include in the common makefile rules
#
ifeq ($(RULES_MAKE_LOADED),)
include $(GNUSTEP_MAKEFILES)/rules.make
endif

#
# The name of the application is in the APP_NAME variable.
# The list of application resource directories is in xxx_RESOURCE_DIRS
# The list of application resource files is in xxx_RESOURCE_FILES
# The list of localized resource files is in xxx_LOCALIZED_RESOURCE_FILES
# The list of supported languages is in xxx_LANGUAGES
# The name of the application icon (if any) is in xxx_APPLICATION_ICON
# The name of the app class is xxx_PRINCIPAL_CLASS (defaults to NSApplication).
# The name of a file containing info.plist entries to be inserted into
# Info-gnustep.plist (if any) is xxxInfo.plist
# where xxx is the application name
#

APP_NAME:=$(strip $(APP_NAME))

# Determine the application directory extension
ifeq ($(profile), yes)
  APP_EXTENSION = profile
else
  ifeq ($(debug), yes)
    APP_EXTENSION = debug
  else
    APP_EXTENSION = app
  endif
endif

ifeq ($(INTERNAL_app_NAME),)
# This part gets included by the first invoked make process.
internal-all:: $(APP_NAME:=.all.app.variables)

internal-install:: $(APP_NAME:=.install.app.variables)

internal-uninstall:: $(APP_NAME:=.uninstall.app.variables)

# Compute them manually to avoid having to do a recursive make
# invocation just to remove them.
_PSWRAP_C_FILES = $(foreach app,$(APP_NAME),$($(app)_PSWRAP_FILES:.psw=.c))
_PSWRAP_H_FILES = $(foreach app,$(APP_NAME),$($(app)_PSWRAP_FILES:.psw=.h))

internal-clean:: $(APP_NAME:=.clean.app.subprojects)
	rm -rf $(GNUSTEP_OBJ_DIR) $(_PSWRAP_C_FILES) $(_PSWRAP_H_FILES)
ifeq ($(OBJC_COMPILER), NeXT)
	rm -f *.iconheader
	for f in *.$(APP_EXTENSION); do \
	  rm -f $$f/`basename $$f .$(APP_EXTENSION)`; \
	done
else
ifeq ($(GNUSTEP_FLATTENED),)
	rm -rf *.$(APP_EXTENSION)/$(GNUSTEP_TARGET_LDIR)
else
	rm -rf *.$(APP_EXTENSION)
endif
endif

internal-distclean:: $(APP_NAME:=.distclean.app.subprojects)
	rm -rf shared_obj static_obj shared_debug_obj shared_profile_obj \
	  static_debug_obj static_profile_obj shared_profile_debug_obj \
	  static_profile_debug_obj *.app *.debug *.profile *.iconheader

$(APP_NAME):
	@$(MAKE) -f $(MAKEFILE_NAME) --no-print-directory $@.all.app.variables

else

.PHONY: internal-app-all \
        internal-app-install \
        internal-app-uninstall \
        before-$(TARGET)-all \
        after-$(TARGET)-all \
        app-resource-files \
        app-localized-resource-files \
        _FORCE

# Libraries that go before the GUI libraries
ALL_GUI_LIBS = $(ADDITIONAL_GUI_LIBS) $(AUXILIARY_GUI_LIBS) $(GUI_LIBS) \
   $(BACKEND_LIBS) $(ADDITIONAL_TOOL_LIBS) $(AUXILIARY_TOOL_LIBS) \
   $(FND_LIBS) $(ADDITIONAL_OBJC_LIBS) $(AUXILIARY_OBJC_LIBS) $(OBJC_LIBS) \
   $(SYSTEM_LIBS) $(TARGET_SYSTEM_LIBS)

ALL_GUI_LIBS := \
    $(shell $(WHICH_LIB_SCRIPT) $(LIB_DIRS_NO_SYSTEM) $(ALL_GUI_LIBS) \
	debug=$(debug) profile=$(profile) shared=$(shared) libext=$(LIBEXT) \
	shared_libext=$(SHARED_LIBEXT))


# Don't include these definitions the first time make is invoked. This part is
# included when make is invoked the second time from the %.build rule (see
# rules.make).
APP_DIR_NAME = $(INTERNAL_app_NAME:=.$(APP_EXTENSION))
APP_RESOURCE_DIRS =  $(foreach d, $(RESOURCE_DIRS), $(APP_DIR_NAME)/Resources/$(d))
ifeq ($(strip $(LANGUAGES)),)
  override LANGUAGES="English"
endif

# Support building NeXT applications
ifneq ($(OBJC_COMPILER), NeXT)
APP_FILE = \
    $(APP_DIR_NAME)/$(GNUSTEP_TARGET_LDIR)/$(INTERNAL_app_NAME)$(EXEEXT)
else
APP_FILE = $(APP_DIR_NAME)/$(INTERNAL_app_NAME)$(EXEEXT)
endif

#
# Internal targets
#

$(APP_FILE): $(OBJ_FILES_TO_LINK)
	$(LD) $(ALL_LDFLAGS) -o $(LDOUT)$@ $(OBJ_FILES_TO_LINK) \
	      $(ALL_FRAMEWORK_DIRS) $(ALL_LIB_DIRS) $(ALL_GUI_LIBS)
ifeq ($(OBJC_COMPILER), NeXT)
	@$(TRANSFORM_PATHS_SCRIPT) $(subst -L,,$(ALL_LIB_DIRS)) \
		>$(APP_DIR_NAME)/library_paths.openapp
# This is a hack for OPENSTEP systems to remove the iconheader file
# automatically generated by the makefile package.
	rm -f $(INTERNAL_app_NAME).iconheader
else
	@$(TRANSFORM_PATHS_SCRIPT) $(subst -L,,$(ALL_LIB_DIRS)) \
	>$(APP_DIR_NAME)/$(GNUSTEP_TARGET_LDIR)/library_paths.openapp
endif

#
# Compilation targets
#
ifeq ($(OBJC_COMPILER), NeXT)
internal-app-all:: before-$(TARGET)-all \
                   $(INTERNAL_app_NAME).iconheader \
                   $(GNUSTEP_OBJ_DIR) \
                   $(APP_DIR_NAME) \
                   $(APP_FILE) \
                   app-resource-files \
                   after-$(TARGET)-all

before-$(TARGET)-all::

after-$(TARGET)-all::

$(INTERNAL_app_NAME).iconheader:
	@(echo "F	$(INTERNAL_app_NAME).$(APP_EXTENSION)	$(INTERNAL_app_NAME)	$(APP_EXTENSION)"; \
	  echo "F	$(INTERNAL_app_NAME)	$(INTERNAL_app_NAME)	app") >$@

$(APP_DIR_NAME):
	mkdir $@

else

internal-app-all:: before-$(TARGET)-all \
                   $(GNUSTEP_OBJ_DIR) \
                   $(APP_DIR_NAME)/$(GNUSTEP_TARGET_LDIR) \
                   $(APP_FILE) \
                   $(APP_DIR_NAME)/$(INTERNAL_app_NAME) \
                   app-resource-files \
                   app-localized-resource-files \
                   after-$(TARGET)-all

before-$(TARGET)-all::

after-$(TARGET)-all::

$(APP_DIR_NAME)/$(GNUSTEP_TARGET_LDIR):
	@$(MKDIRS) $(APP_DIR_NAME)/$(GNUSTEP_TARGET_LDIR)

ifeq ($(GNUSTEP_FLATTENED),)
$(APP_DIR_NAME)/$(INTERNAL_app_NAME):
	cp $(GNUSTEP_MAKEFILES)/executable.template \
	   $(APP_DIR_NAME)/$(INTERNAL_app_NAME); \
	chmod a+x $(APP_DIR_NAME)/$(INTERNAL_app_NAME)
endif
endif

$(APP_RESOURCE_DIRS):
	$(MKDIRS) $(APP_RESOURCE_DIRS)

app-resource-files:: $(APP_DIR_NAME)/Resources/Info-gnustep.plist \
                     $(APP_RESOURCE_DIRS)
ifneq ($(strip $(RESOURCE_FILES)),)
	@(echo "Copying resources into the application wrapper..."; \
	cp -r $(RESOURCE_FILES) $(APP_DIR_NAME)/Resources;)
endif

app-localized-resource-files:: $(APP_DIR_NAME)/Resources/Info-gnustep.plist \
                               $(APP_RESOURCE_DIRS)
ifneq ($(strip $(LOCALIZED_RESOURCE_FILES)),)
	@(echo "Copying localized resources into the application wrapper..."; \
	for l in $(LANGUAGES); do \
	  if [ -d $$l.lproj ]; then \
	    $(MKDIRS) $(APP_DIR_NAME)/Resources/$$l.lproj; \
	    for f in $(LOCALIZED_RESOURCE_FILES); do \
	      if [ -f $$l.lproj/$$f ]; then \
	        cp -r $$l.lproj/$$f $(APP_DIR_NAME)/Resources/$$l.lproj; \
	      fi; \
	    done; \
	  else \
	    echo "Warning: $$l.lproj not found - ignoring"; \
	  fi; \
	done;)
endif

ifeq ($(PRINCIPAL_CLASS),)
override PRINCIPAL_CLASS = NSApplication
endif

$(APP_DIR_NAME)/Resources/Info-gnustep.plist: $(APP_DIR_NAME)/Resources _FORCE
	@(echo "{"; echo '  NOTE = "Automatically generated, do not edit!";'; \
	  echo "  NSExecutable = \"$(INTERNAL_app_NAME)\";"; \
	  if [ "$(MAIN_MODEL_FILE)" = "" ]; then \
	    echo "  NSMainNibFile = \"\";"; \
	  else \
	    echo "  NSMainNibFile = \"$(subst .gmodel,,$(subst .gorm,,$(subst .nib,,$(MAIN_MODEL_FILE))))\";"; \
	  fi; \
	  if [ "$(APPLICATION_ICON)" != "" ]; then \
	    echo "  NSIcon = \"$(APPLICATION_ICON)\";"; \
	  fi; \
	  echo "  NSPrincipalClass = \"$(PRINCIPAL_CLASS)\";"; \
	  echo "}") >$@
	  @ if [ -r "$(INTERNAL_app_NAME)Info.plist" ]; then \
	    plmerge $@ $(INTERNAL_app_NAME)Info.plist; \
	  fi

$(APP_DIR_NAME)/Resources:
	@$(MKDIRS) $@

_FORCE::

internal-app-install:: $(GNUSTEP_APPS)
	rm -rf $(GNUSTEP_APPS)/$(APP_DIR_NAME); \
	$(TAR) cf - $(APP_DIR_NAME) | (cd $(GNUSTEP_APPS); $(TAR) xf -)
ifneq ($(CHOWN_TO),)
	$(CHOWN) -R $(CHOWN_TO) $(GNUSTEP_APPS)/$(APP_DIR_NAME)
endif
ifeq ($(strip),yes)
	$(STRIP) $(GNUSTEP_APPS)/$(APP_FILE)
endif


$(GNUSTEP_APPS):
	$(MKINSTALLDIRS) $(GNUSTEP_APPS)

internal-app-uninstall::
	(cd $(GNUSTEP_APPS); rm -rf $(APP_DIR_NAME))

endif

endif
# application.make loaded

## Local variables:
## mode: makefile
## End:

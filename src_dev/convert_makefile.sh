#!/bin/bash

# NOTE: the script rewrites ./Makefile and ./Makefile.bak of the CURRENT directory,
# therefore it must be run from src/ (the directory that now holds the Makefile):
#
#     cd src && ./convert_makefile.sh
#
# The script is a legacy helper that converted the original mkmf-generated Makefile:
# it still works with its own OBJDIR = obj, while the current Makefile builds into
# the repository-level ../build/obj and links ../build/TEB_offline.exe.
#
# Final script to convert Makefile:
# - keep dependency rules, remove compilation commands
# - add $(OBJDIR)/ prefix to targets and dependencies
# - remove cp and localize rules
# - add module flags directly in Makefile after OBJDIR is defined
# - add include flags
# - add generic rules and vpath

set -e

MAKEFILE="Makefile"
BACKUP="${MAKEFILE}.bak"
OBJDIR="obj"

echo "=== Converting Makefile to build into $OBJDIR directory ==="

# 1. Backup
if [ -f "$MAKEFILE" ]; then
    cp "$MAKEFILE" "$BACKUP"
    echo "Backup created: $BACKUP"
else
    echo "Error: $MAKEFILE not found!"
    exit 1
fi

# 2. Remove old compilation command lines (starting with tab and $(FC))
sed -i '/^[[:space:]]*$(FC)/d' "$MAKEFILE"
echo "Removed old compilation commands."

# 3. Remove all cp commands (lines starting with tab and cp)
sed -i '/^[[:space:]]*cp /d' "$MAKEFILE"
echo "Removed all cp commands."

# 4. Remove localize target and its dependencies
sed -i '/^localize:/d' "$MAKEFILE"
sed -i '/^OFF = /d' "$MAKEFILE"
echo "Removed localize and OFF."

# 5. Add OBJDIR and mkdir after include
sed -i "/^include gfortran_args/a OBJDIR = $OBJDIR\n\$(shell mkdir -p \$(OBJDIR))" "$MAKEFILE"
echo "Added OBJDIR and mkdir."

# 6. Add module and include flags right after OBJDIR definition
sed -i "/^OBJDIR = $OBJDIR/a \\\\n# Ensure module files go to OBJDIR and include paths are set\nifeq (\$(FC),ifort)\n    FFLAGS += -module \$(OBJDIR) -I. -Isrc_teb\nelse\n    FFLAGS += -J\$(OBJDIR) -I. -Isrc_teb\nendif" "$MAKEFILE"
echo "Added module and include flags to Makefile."

# 7. Redefine OBJ list with prefix $(OBJDIR)/
sed -i 's/^OBJ = /OBJ = \$(addprefix \$(OBJDIR)\/, /' "$MAKEFILE"
sed -i '/^OBJ = \$(addprefix .*/ s/$/)/' "$MAKEFILE"
echo "Updated OBJ list with path to $OBJDIR."

# 8. Transform all rule targets and dependencies to include $(OBJDIR)/
sed -i '/:/s/ \([^ ]*\)\.o/ $(OBJDIR)\/\1.o/g; s/^\([^ ]*\)\.o:/$(OBJDIR)\/\1.o:/' "$MAKEFILE"
echo "Updated rule targets and dependencies to use $(OBJDIR)/."

# 9. Remove lines starting with './' (copy rules for localize)
sed -i '/^\.\//d' "$MAKEFILE"
echo "Removed localize copy rules."

# 10. Append generic build rules and vpath (fallback)
cat >> "$MAKEFILE" << 'EOF'

# ----- Generic rules for building into obj/ (fallback) -----
vpath %.F90 src_driver src_teb src_struct src_proxi_SVAT src_solar
vpath %.f90 src_driver src_teb src_struct src_proxi_SVAT src_solar
vpath %.F   src_teb
vpath %.f   src_teb

$(OBJDIR)/%.o: %.F90 | $(OBJDIR)
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c $< -o $@

$(OBJDIR)/%.o: %.f90 | $(OBJDIR)
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c $< -o $@

$(OBJDIR)/%.o: %.F | $(OBJDIR)
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c $< -o $@

$(OBJDIR)/%.o: %.f | $(OBJDIR)
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) $(OTHERFLAGS) -c $< -o $@
EOF

# 11. Fix driver1.exe rule
sed -i '/^driver1.exe:/c driver1.exe: $(OBJ) | $(OBJDIR)' "$MAKEFILE"
sed -i '/^driver1.exe:.*/a \\t$(LD) $(OBJ) -o driver1.exe $(LDFLAGS)' "$MAKEFILE"

# 12. Update clean: remove obj/ and all .mod files anywhere
sed -i '/^clean:/a \\t-rm -f $(shell find . -name "*.mod" 2>/dev/null)' "$MAKEFILE"
sed -i '/^clean:/a \\t-rm -rf $(OBJDIR)' "$MAKEFILE"

echo "Added generic compilation rules, fixed driver1.exe and clean."

echo "=== Conversion completed! ==="
echo "Run 'make clean && make' to build."
echo "Backup: $BACKUP"
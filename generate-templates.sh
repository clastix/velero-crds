#!/bin/bash

# Generate Helm templates from CRDs by copying full CRDs and replacing labels/annotations with templating
CRDS_DIR="crds"
CHART_DIR="chart"
TEMPLATES_DIR="$CHART_DIR/templates"

mkdir -p "$TEMPLATES_DIR"

# Process each CRD file
for crd_file in "$CRDS_DIR"/*.yaml; do
    base_name=$(basename "$crd_file")
    echo "Processing $base_name..."
    
    # Extract CRD name for templating
    crd_name=$(yq eval '.metadata.name' "$crd_file")
    
    # Create a proper Helm template by manually constructing it
    {
        # Start with the document separator and API info
        echo "---"
        echo "apiVersion: $(yq eval '.apiVersion' "$crd_file")"
        echo "kind: $(yq eval '.kind' "$crd_file")"
        
        # Start metadata section
        echo "metadata:"
        echo "  name: $crd_name"
        
        # Add Helm templating for labels
        echo "  labels:"
        echo "{{- include \"velero-crds.labels\" . | nindent 4 }}"
        echo "{{- \$crdKey := printf \"%s\" \"$crd_name\" | replace \".\" \"_\" }}"
        echo "{{- if .Values.crds }}"
        echo "{{- with (index .Values.crds \$crdKey).metadata.labels }}"
        echo "{{- toYaml . | nindent 4 }}"
        echo "{{- end }}"
        echo "{{- end }}"
        
        # Add Helm templating for annotations
        echo "  annotations:"
        echo "{{- if .Values.crds }}"
        echo "{{- with (index .Values.crds \$crdKey).metadata.annotations }}"
        echo "{{- toYaml . | nindent 4 }}"
        echo "{{- end }}"
        echo "{{- end }}"
        
        # Copy the spec section as-is
        echo "spec:"
        yq eval '.spec' "$crd_file" | sed 's/^/  /'
    } > "$TEMPLATES_DIR/$base_name"
    
    echo "  -> Created $TEMPLATES_DIR/$base_name with Helm templating"
done

echo "Template generation complete!"
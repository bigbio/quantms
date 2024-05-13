#!/usr/bin/env python
# Add extra features in sage idXML. Adding extra feature in Sage isn't known input for PSMFeatureExtractor

import pyopenms as oms
import pandas as pd
import sys


def add_feature(idx_file, output_file, feat_file):
    extra_feat = []
    feat = pd.read_csv(feat_file, sep='\t')
    for _, row in feat.iterrows():
        if row["feature_generator"] == 'psm_file':
            continue
        else:
            extra_feat.append(row["feature_name"])
    print("Adding extra feature: {}".format(extra_feat))
    protein_ids = []
    peptide_ids = []
    oms.IdXMLFile().load(idx_file, protein_ids, peptide_ids)
    SearchParameters = protein_ids[0].getSearchParameters()
    features = SearchParameters.getMetaValue("extra_features")
    extra_features = features + "," + ",".join(extra_feat)
    SearchParameters.setMetaValue("extra_features", extra_features)
    protein_ids[0].setSearchParameters(SearchParameters)
    oms.IdXMLFile().store(output_file, protein_ids, peptide_ids)
    print("Done")


def main():
    idx_file = sys.argv[1]
    output_file = sys.argv[2]
    feat_file = sys.argv[3]
    add_feature(idx_file, output_file, feat_file)


if __name__ == "__main__":
    sys.exit(main())

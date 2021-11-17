#!/usr/bin/env python
from __future__ import print_function
import os
import re

results = {}
version_files = [x for x in os.listdir(".") if x.endswith(".version.txt")]

# TODO https://github.com/nf-core/proteomicslfq/pull/165
def get_versions(software, version_file):
    semver_regex = r"((?P<major>0|[1-9]\d*)\.(?P<minor>0|[1-9]\d*)\.(?P<patch>0|[1-9]\d*)(?:-(?P<prerelease>(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+(?P<buildmetadata>[0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?)"

    regexes = {
        'nf-core/quantms': r"(\S+)",
        'nextflow': r"(\S+)",
        'sdrf-pipelines': semver_regex,
        'thermorawfileparser': r"(\S+)",
        'fileconverter':  semver_regex,
        'decoydatabase':  semver_regex,
        'isobaricanalyzer': semver_regex,
        'msgfplusadapter': semver_regex,
        'msgfplus': r"\(([^v)]+)\)",
        'cometadapter': semver_regex,
        'comet': r"\"(.*)\"",
        'indexpeptides': semver_regex,
        'extractpsmfeature': semver_regex,
        'percolatoradapter': semver_regex,
        'percolator': r"([0-9].[0-9]{2}.[0-9])",
        'idfilter': semver_regex,
        'idscoreswitcher': semver_regex,
        'falsediscoveryrate': semver_regex,
        'IDPosteriorErrorProbability': semver_regex,
        'consensusid': semver_regex,
        'filemerge': semver_regex,
        'idmapper': semver_regex,
        'epifany': semver_regex,
        'proteininference': semver_regex,
        'idconflictresolver': semver_regex,
        'proteomicslfq': semver_regex,
        'proteinquantifier': semver_regex,
        'msstatsconverter': semver_regex,
        'msstats': r"(\S+)"
    }

    match = re.search(regexes[software], version_file).group(1)
    return match

for version_file in version_files:

    software = version_file.replace(".version.txt", "")
    if software == "pipeline":
        software = "nf-core/quantms"

    with open(version_file) as fin:
        version = get_versions(software, fin.read().strip())
    results[software] = version

# Dump to YAML
print(
    """
id: 'software_versions'
section_name: 'nf-core/quantms Software Versions'
section_href: 'https://github.com/nf-core/quantms'
plot_type: 'html'
description: 'are collected at run time from the software output.'
data: |
    <dl class="dl-horizontal">
"""
)
for k, v in sorted(results.items()):
    print("        <dt>{}</dt><dd><samp>{}</samp></dd>".format(k, v))
print("    </dl>")

# Write out as tsv file:
with open("software_versions.tsv", "w") as f:
    for k, v in sorted(results.items()):
        f.write("{}\t{}\n".format(k, v))

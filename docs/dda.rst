Data-dependent acquisition (DDA) quantification
===============================================

In bottom-up proteomics, the DDA method is used to collect tandem MS spectra
for peptide identification and is combined with conceptually different techniques
for peptide quantify analytes.

Existing techniques can be loosely categorized in labeled and label-free approaches. Two major analytical techniques
dominates currently DDA approaches, Isobariq methods and Label-free (LFQ) methods. DDA quantification methods shared
multiple steps including: protein digestion, peptide fractionation and are mainly different in the way peptides from difference
samples are multiplex in the (MS) run.

Label-free quantification (LFQ) is probably the most direct way of determining quantities of
analytes from several biological samples as they detect and integrate chromatographic
intensities of a peptide. To quantify across several MS runs corresponding peptide signals, so-called
features, need to be linked between runs. While label-free quantification scales to a large
number of experiments, it heavily relies on correct linking of corresponding peptides (read more details :doc:`lfq`).

Isobaric labeling , (TMT in particular) circumvent, to some extent, the problem of
linking corresponding peptides as they multiplex more than one peptide from each experimental condition
in a single MS run (read more details :doc:`iso`).

Label-free and Labeled methods share multiple steps of the DDA data analysis including: :doc:`identification`, :doc:`modlocal`.
Both labeled and label-free quantification techniques yield **relative quantities** for an analyte and can
be used to calculate *fold changes* between conditions. quantms is mainly focus on differential expression data analysis,
but absolute expression is also possible to perform (read more :doc:`absolute`)


.. toctree::
   :maxdepth: 2

   identification
   lfq
   iso
   inference
   modlocal

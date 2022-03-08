Data-dependent acquisition (DDA) quantification
===============================================

In bottom-up proteomics, DDA is used to collect tandem MS spectra for identification 
is combined with differnt techniques to quantify analytes.
Existing techniques can be loosely categorized in labeled and label-free approaches.
Label-free quantification (LFQ) is probably the most direct way of determining quantities of
analytes from several biological samples as they detect and integrate chromatographic 
intensities of a peptide. To quantify across several MS runs corresponding peptide signals, so-called
features, need to be linked between runs. While label-free quantification scales to a large
number of experiments, it heavily relies on correct linking of corresponding peptides.
Labeling techniques, like isobaric labeling, circumvent, to some extent, the problem of 
linking corresponding peptides as they allow measuring more than one experimental condition 
in a single MS run.

.. toctree::
   :maxdepth: 2

   identification
   iso
   lfq
   inference

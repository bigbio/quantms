Comet search engine
===================

`Comet <https://github.com/UWPR/Comet>`_ [ENG2015]_ is an **open source** tandem mass spectrometry (MS/MS) sequence database search
tool released under the Apache 2.0 license. Among some of the main features of the algorithm are: multithreading, speed and
memory allocation.

.. note:: In quantms, comet has proved to be faster compare with :doc:`msgf` while identifying less than **15%** PSMs. In addition, comet consume less memory than :doc:`msgf` in general, while consuming more CPU.

.. image:: images/resources-search-engine.png
   :width: 800
   :align: center

In quantms, PSMs are exported from the search engine into .idXML (read more :doc:`formats`) without filtering for the re-scoring (see :doc:`identification`) step with percolator. The pipeline stores these original file results in the result folder under `searchenginecomet`.

References
------------------

.. [ENG2015]
Comet: an open source tandem mass spectrometry sequence database search tool. Eng JK, Jahan TA, Hoopmann MR. Proteomics. 2012 Nov 12. doi: 10.1002/pmic.201200439
A Deeper Look into Comet - Implementation and Features. Eng JK, Hoopmann MR, Jahan TA, Egertson JD, Noble WS, MacCoss MJ. J Am Soc Mass Spectrom. 2015 Jun 27. doi: 10.1007/s13361-015-1179-x

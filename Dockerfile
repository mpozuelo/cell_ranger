FROM nfcore/base:1.9
LABEL authors="Marta Pozuelo del Rio" \
      description="Docker image containing all requirements for the mpozuelo/cell_ranger pipeline"

# Install the conda environment
COPY environment.yml /
RUN conda env create -f /environment.yml && conda clean -a

# Add conda installation dir to PATH (instead of doing 'conda activate')
ENV PATH /opt/conda/envs/mpozuelo-cell_ranger-1.0/bin:$PATH

# Dump the details of the installed packages to a file for posterity
RUN conda env export --name mpozuelo-cell_ranger-1.0 > mpozuelo-cell_ranger-1.0.yml

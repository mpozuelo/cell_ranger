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


#install cell cellRanger
RUN \
  set -x \
  yum update -y && \
  yum install -y \
  wget \
  which && \
  yum clean all

ENV CELLRANGER_VER 1.3.1

# Pre-downloaded file
COPY cellranger-$CELLRANGER_VER.tar.gz /opt/cellranger-$CELLRANGER_VER.tar.gz

RUN \
  cd /opt && \
  tar -xzvf cellranger-$CELLRANGER_VER.tar.gz && \
  export PATH=/opt/cellranger-$CELLRANGER_VER:$PATH && \
  ln -s /opt/cellranger-$CELLRANGER_VER/cellranger /usr/bin/cellranger && \
  rm -rf /opt/cellranger-$CELLRANGER_VER.tar.gz

CMD ["cellranger"]

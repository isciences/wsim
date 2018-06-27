FROM isciences/wsim-gitlabci:latest

COPY wsim.io /wsim/wsim.io
WORKDIR /wsim/wsim.io
RUN make install

COPY wsim.lsm /wsim/wsim.lsm
WORKDIR /wsim/wsim.lsm
RUN make install

COPY wsim.distributions /wsim/wsim.distributions
WORKDIR /wsim/wsim.distributions
RUN make install

COPY workflow /wsim/workflow
WORKDIR /wsim/workflow
RUN make install

COPY utils /wsim/utils
COPY *.R /wsim/

COPY Makefile /wsim/

WORKDIR /wsim


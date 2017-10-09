FROM isciences/wsim-gitlabci

COPY . /wsim
WORKDIR /wsim
RUN make install


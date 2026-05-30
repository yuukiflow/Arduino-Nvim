# Pickers package

This package is intended to store code for multiple pickers backend.
All backends MUST to expose the following methods:

- select_board
- select_port
- select_board_and_port
- open_library_manager

Right now, none of them needs to support input data since all of them have access to the other packages to get the relevand data.

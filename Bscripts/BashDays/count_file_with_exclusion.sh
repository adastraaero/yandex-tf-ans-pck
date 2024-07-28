#!/bin/bash
find . -type f -not -path "*6b*" | wc -l >> summ.txt

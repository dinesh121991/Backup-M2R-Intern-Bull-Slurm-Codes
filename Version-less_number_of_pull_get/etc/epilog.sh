#!/bin/sh

#/usr/local/slurm267/etc/mergehdf5 --jobid=$SLURM_JOBID
/usr/local/slurm267/etc/mergehdf5 --profiledir=/home_nfs/testfs/slurm_hdf5_logs --jobid=$SLURM_JOB_ID --savefiles 

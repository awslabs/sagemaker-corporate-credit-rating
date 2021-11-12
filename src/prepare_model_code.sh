#!/bin/bash 
if [[ ! -d "./model-training/lib" ]] 
then
    mkdir model-training/lib
	tar -zxvf python-dependencies/autogluon.tar.gz -C model-training/lib --strip-components=1 --no-same-owner 
	cd model-training/lib && ls > ../requirements.txt && sed -i -e 's#^#lib/#' ../requirements.txt
    cd ../..
	echo "Files for training are created."
else
	echo "Files for training exist."	
fi


if [[ ! -d "./model-inference/lib" ]] 
then
    mkdir model-inference/lib
	tar -zxvf python-dependencies/autogluon.tar.gz -C model-inference/lib --strip-components=1 --no-same-owner
	cd model-inference/lib && ls > ../requirements.txt && sed -i -e 's#^#/opt/ml/model/code/lib/#' ../requirements.txt
    cd ../..
	echo "Files for inference are created."
else
	echo "Files for inference exist."	
fi
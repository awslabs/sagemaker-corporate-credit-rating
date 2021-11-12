#!/bin/bash
set -euxo pipefail

NOW=$(date +"%x %r %Z")
echo "Time: $NOW"

if [ $# -lt 3 ]; then
    echo "Please provide the solution name as well as the base S3 bucket name and the region to run build script."
    echo "For example: ./scripts/build.sh trademarked-solution-name sagemaker-solutions-build us-west-2"
    exit 1
fi

REGION=$3
SOURCE_REGION="us-west-2"
echo "Region: $REGION, source region: $SOURCE_REGION"
BASE_DIR="$(dirname "$(dirname "$(readlink -f "$0")")")"
echo "Base dir: $BASE_DIR"

rm -rf build
mkdir build

for nb in src/*.ipynb; do
    python "$BASE_DIR"/scripts/set_kernelspec.py --notebook "$nb" --display-name "Python 3 (Data Science)" --kernel "HUB_1P_IMAGE"
done

echo "create nb dependencies wheels"
python -m pip wheel --wheel-dir=wheelhouse -r scripts/notebook-requirements/nb_requirements.txt

echo "Solution assistant lambda function"
cd cloudformation/solution-assistant/ || exit
python -m pip install -r requirements.txt -t ./src/site-packages

cd -

echo "Clean up pyc files, needed to avoid security issues. See: https://blog.jse.li/posts/pyc/"
find cloudformation/ -type f -name "*.pyc" -delete
find cloudformation/ -type d -name "__pycache__" -delete
cp -r cloudformation/solution-assistant/src build/
cd build/src || exit
zip -q -r9 "$BASE_DIR"/build/solution-assistant.zip -- *

cd -
rm -rf build/src

if [ -z "$4" ] || [ "$4" == 'mainline' ]; then
    s3_prefix="s3://$2-$3/$1"
else
    s3_prefix="s3://$2-$3/$1-$4"
fi

echo "Removing the existing objects under $s3_prefix"
aws s3 rm --recursive "$s3_prefix" --region "$REGION"
echo "Copying new objects to $s3_prefix"
aws s3 sync . "$s3_prefix" --delete --region "$REGION" \
    --exclude ".git/*" \
    --exclude ".git*" \
    --exclude ".vscode/*" \
    --exclude ".mypy_cache/*"

echo "Copying solution artifacts"
aws s3 cp "s3://sagemaker-solutions-artifacts/sagemaker-corporate-credit-rating/model.tar.gz" "$s3_prefix"/build/model.tar.gz --source-region "$SOURCE_REGION"
aws s3 sync "s3://sagemaker-solutions-artifacts/sagemaker-corporate-credit-rating/data" "$s3_prefix"/data --delete --region "$REGION"
aws s3 sync "s3://sagemaker-solutions-artifacts/sagemaker-corporate-credit-rating/python-dependencies" "$s3_prefix"/python-dependencies --delete --region "$REGION"

echo "Copying notebook dependencies"
aws s3 sync "$BASE_DIR"/wheelhouse "$s3_prefix"/python-dependencies/wheelhouse --delete --region "$REGION"
rm -rf wheelhouse
import logging
import pandas as pd
import numpy as np
import json
import zipfile
from sklearn.model_selection import train_test_split
from sklearn.compose import ColumnTransformer
from sklearn.pipeline import Pipeline
from sklearn.impute import SimpleImputer
from sklearn.preprocessing import OneHotEncoder
from sklearn.base import BaseEstimator, TransformerMixin
from sklearn.cluster import KMeans
from sklearn.metrics import mean_absolute_error
from xgboost import XGBRegressor
from collections import Counter

class FeatureEngineer(BaseEstimator, TransformerMixin):
    def __init__(self, kmeans_model=None):
        self.kmeans_model = kmeans_model

    def fit(self, X, y=None):
        if self.kmeans_model is None:
            self.kmeans_model = KMeans(n_clusters=10, random_state=123)
            self.kmeans_model.fit(X[['lat', 'lon']])
        return self

    def transform(self, X):
        X_ = X.copy()
        X_['num_reviews_log'] = np.log1p(X_['num_reviews'])
        X_['rating_sq'] = X_['rating'] ** 2
        X_['rating_bin'] = pd.cut(X_['rating'], bins=[-np.inf, 3, 4.5, np.inf], labels=[0,1,2]).astype(int)
        X_['guests_sq'] = X_['guests'] ** 2
        X_['rating_x_reviews'] = X_['rating'] * X_['num_reviews_log']
        X_['guests_x_rating'] = X_['guests'] * X_['rating']
        X_['location_cluster'] = self.kmeans_model.predict(X[['lat', 'lon']])
        return X_

def extract_facilities(df, top_k=20):
    df['facilities_list'] = df['facilities'].fillna("").apply(lambda x: x.split())
    all_facilities = [fac for sublist in df['facilities_list'] for fac in sublist]
    most_common = [item for item, _ in Counter(all_facilities).most_common(top_k)]

    for facility in most_common:
        df[f'has_{facility}'] = df['facilities_list'].apply(lambda lst: int(facility in lst))

    return df.drop(columns=['facilities_list'])

def baseline():
    logging.info("Reading train and test files")
    train = pd.read_json("train.json", orient='records')
    test = pd.read_json("test.json", orient='records')

    train = extract_facilities(train)
    test = extract_facilities(test)

    for df in [train, test]:
        df["num_facilities"] = df["facilities"].str.split().apply(len)

    facility_features = [col for col in train.columns if col.startswith("has_")]

    numerical_features = ["lat", "lon", "rooms", "beds", "bathrooms", "guests", "num_reviews",
                          "min_nights", "rating", "num_facilities", "num_reviews_log", "rating_sq",
                          "rating_bin", "guests_sq", "rating_x_reviews", "guests_x_rating"] + facility_features
    categorical_features = ["room_type", "listing_type", "cancellation", "location_cluster"]

    preprocess = ColumnTransformer(
        transformers=[
            ("num", Pipeline([
                ("imputer", SimpleImputer(strategy='mean')),
            ]), numerical_features),
            ("cat", Pipeline([
                ("imputer", SimpleImputer(strategy='most_frequent')),
                ("encoder", OneHotEncoder(handle_unknown='ignore')),
            ]), categorical_features)])

    label = 'revenue'

    model = Pipeline([
        ("feature_engineering", FeatureEngineer()),
        ("preprocess", preprocess),
        ("regressor", XGBRegressor(
            n_estimators=500, learning_rate=0.05, max_depth=4,
            subsample=0.8, colsample_bytree=0.7, reg_lambda=1.0,
            random_state=123, n_jobs=-1))])

    train_data, valid_data = train_test_split(train, test_size=1/3, random_state=123)

    logging.info("Training model")
    model.fit(train_data.drop(columns=[label]), np.log1p(train_data[label]))

    for split_name, split in [("train", train_data), ("valid", valid_data)]:
        preds = np.expm1(model.predict(split.drop(columns=[label])))
        mae = mean_absolute_error(split[label], preds)
        logging.info(f"{split_name} MAE: {mae:.3f}")

    logging.info("Training final model on full training data")
    model.fit(train.drop(columns=[label]), np.log1p(train[label]))

    logging.info("Predicting test data")
    preds_test = np.expm1(model.predict(test))

    test[label] = preds_test
    predicted = test[[label]].to_dict(orient='records')

    with zipfile.ZipFile("predicted.zip", "w", zipfile.ZIP_DEFLATED) as zipf:
        zipf.writestr("predicted.json", json.dumps(predicted, indent=2))

if __name__ == "__main__":
    logging.getLogger().setLevel(logging.INFO)
    baseline()

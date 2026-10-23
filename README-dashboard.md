# StreamPulse dashboard starter

1. Copy `app.py` and `requirements-dashboard.txt` into the root of your existing `E:\\streampulse` repository.
2. Create `data\\tableau` and copy the eight CSVs from `results\\_SYNTHETIC_TEST_ONLY\\tableau` into it.
3. In your activated virtual environment run:
   ```powershell
   pip install -r requirements-dashboard.txt
   streamlit run app.py
   ```
4. Once local testing works, push the dashboard files and CSVs to GitHub only if you're comfortable making the synthetic demo exports public.
5. On Streamlit Community Cloud, create an app from `shrey200511/streampulse`, select the deployment branch and set main file path to `app.py`.

The cloud app cannot read your local Windows drive. The data CSVs must be present in the deployed repository or fetched from a hosted data source. The displayed outputs are synthetic smoke-test data, not validated business results.

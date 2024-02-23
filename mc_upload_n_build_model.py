import os
import datetime
import subprocess
import pandas as pd
from pathlib import Path

def upload_to_mc(mc_workspace_id, file_abs_path, mc_data_dir):
    cmd = f"""
    export JUPYTERHUB_SERVER_NAME={mc_workspace_id}
    export MIRACLE_ENDPOINT=https://bio-top.miracle.ac.cn
    export MIRACLE_ACCESS_KEY=AKLTNmJmODllMWNiNDQ3NDE2NzhmYmZjMTlhOTVlY2QwOGM
    export MIRACLE_SECRET_KEY=TXpSa1lXVm1ZVGd5TnpSbU5Ea3pOamhpTldFM01EZ3daamsyTnpWbU5qRQ==
    nohup miraclecloud.cli upload {file_abs_path} {mc_data_dir} &
    """
    subprocess.run(cmd, shell=True)

if __name__ == '__main__':
    mc_workspace_id = 'wcjtd2nleig45hpncsc2g'
    mc_data_dir = 'fast5'
    data_model = []
    for fast5_abs in [i.resolve() for i in list(Path('fast5').glob('**/*.fast5'))]:
        # upload_to_mc(mc_workspace_id, str(fast5_abs), mc_data_dir)
        data_model.append({'sample_id': fast5_abs.name.split('.fast5')[0],
                           'fast5_path': f's3://bioos-{mc_workspace_id}/{mc_data_dir}/{fast5_abs.name}',
                           'date': datetime.datetime.now().strftime('%Y-%m-%d_%H:%M:%S')})
    pd.DataFrame(data_model).to_csv('data_model.csv', index=False)



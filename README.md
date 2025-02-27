# <img src="./utils/media/ai_foundry.png" alt="Azure Foundry" style="width:80px;height:30px;"/> Azure AI Foundry Workshop Notebooks

This directory contains Jupyter notebooks for hands-on exercises with Azure AI Foundry.

## Instructions

1. **Python Environment Setup**
   ```bash
   python3.11 -m venv .venv
   source .venv/bin/activate  # On Windows: .venv\Scripts\activate
   pip install -r requirements.txt
   ```

2. **Create the infrastructure**
   You'll need to set up the following environment variables:

   - Run the [1-create-infra](../ai-foundry-workshop/1-infra/1-create-infra.ipynb)
   
   After running, an `.env` file will be created with all necessary environment variables

3. **Running the Notebooks**
   - Open each [notebook's folder](../ai-foundry-workshop/2-notebooks/)

4. **Delete the Resources**
   - Run the [2-clean-up-resources](../ai-foundry-workshop/1-infra/2-clean-up-resources.ipynb)


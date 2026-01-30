 Mounted at /content/drive
DB_PATH = /content/drive/Othercomputers/マイ ノートパソコン/Google Drive/10_diamond_pj/db/main.db

  
    

    .dataframe tbody tr th:only-of-type {
        vertical-align: middle;
    }

    .dataframe tbody tr th {
        vertical-align: top;
    }

    .dataframe thead th {
        text-align: right;
    }


  
    
      
      table_name
    
  
  
    
      0
      bars
    
    
      1
      dim_calendar
    
    
      2
      dim_master
    
    
      3
      fact_earnings_calendar
    
    
      4
      fact_fins_summary
    
    
      5
      fact_investor_types
    
    
      6
      fact_price
    
    
      7
      fact_price_raw
    
    
      8
      fact_topix
    
    
      9
      ingest_daily_status
    
    
      10
      listed_info
    
    
      11
      trading_calendar
    
    
      12
      v_bars
    
    
      13
      v_bars_raw
    
  


    

  
    

  
    
  
    

  
    .colab-df-container {
      display:flex;
      gap: 12px;
    }

    .colab-df-convert {
      background-color: #E8F0FE;
      border: none;
      border-radius: 50%;
      cursor: pointer;
      display: none;
      fill: #1967D2;
      height: 32px;
      padding: 0 0 0 0;
      width: 32px;
    }

    .colab-df-convert:hover {
      background-color: #E2EBFA;
      box-shadow: 0px 1px 2px rgba(60, 64, 67, 0.3), 0px 1px 3px 1px rgba(60, 64, 67, 0.15);
      fill: #174EA6;
    }

    .colab-df-buttons div {
      margin-bottom: 4px;
    }

    [theme=dark] .colab-df-convert {
      background-color: #3B4455;
      fill: #D2E3FC;
    }

    [theme=dark] .colab-df-convert:hover {
      background-color: #434B5C;
      box-shadow: 0px 1px 3px 1px rgba(0, 0, 0, 0.15);
      filter: drop-shadow(0px 1px 2px rgba(0, 0, 0, 0.3));
      fill: #FFFFFF;
    }
  

    
      const buttonEl =
        document.querySelector('#df-8db14700-cff1-4aca-989d-ef3b323082f1 button.colab-df-convert');
      buttonEl.style.display =
        google.colab.kernel.accessAllowed ? 'block' : 'none';

      async function convertToInteractive(key) {
        const element = document.querySelector('#df-8db14700-cff1-4aca-989d-ef3b323082f1');
        const dataTable =
          await google.colab.kernel.invokeFunction('convertToInteractive',
                                                    [key], {});
        if (!dataTable) return;

        const docLinkHtml = 'Like what you see? Visit the ' +
          '<a target="_blank" href=https://colab.research.google.com/notebooks/data_table.ipynb>data table notebook</a>'
          + ' to learn more about interactive tables.';
        element.innerHTML = '';
        dataTable['output_type'] = 'display_data';
        await google.colab.output.renderOutput(dataTable, element);
        const docLink = document.createElement('div');
        docLink.innerHTML = docLinkHtml;
        element.appendChild(docLink);
      }
    
  


  
    
      .colab-df-generate {
        background-color: #E8F0FE;
        border: none;
        border-radius: 50%;
        cursor: pointer;
        display: none;
        fill: #1967D2;
        height: 32px;
        padding: 0 0 0 0;
        width: 32px;
      }

      .colab-df-generate:hover {
        background-color: #E2EBFA;
        box-shadow: 0px 1px 2px rgba(60, 64, 67, 0.3), 0px 1px 3px 1px rgba(60, 64, 67, 0.15);
        fill: #174EA6;
      }

      [theme=dark] .colab-df-generate {
        background-color: #3B4455;
        fill: #D2E3FC;
      }

      [theme=dark] .colab-df-generate:hover {
        background-color: #434B5C;
        box-shadow: 0px 1px 3px 1px rgba(0, 0, 0, 0.15);
        filter: drop-shadow(0px 1px 2px rgba(0, 0, 0, 0.3));
        fill: #FFFFFF;
      }
    
    

  
    
  
    
    
      (() => {
      const buttonEl =
        document.querySelector('#id_48b43fc5-bb20-4f63-a4a9-ea27c4b42bd4 button.colab-df-generate');
      buttonEl.style.display =
        google.colab.kernel.accessAllowed ? 'block' : 'none';

      buttonEl.onclick = () => {
        google.colab.notebook.generateWithVariable('tables');
      }
      })();
    
  

    
  

  
    

    .dataframe tbody tr th:only-of-type {
        vertical-align: middle;
    }

    .dataframe tbody tr th {
        vertical-align: top;
    }

    .dataframe thead th {
        text-align: right;
    }


  
    
      
      table_name
      rows
    
  
  
    
      0
      bars
      5235019
    
    
      1
      v_bars
      5235019
    
  


    

  
    

  
    
  
    

  
    .colab-df-container {
      display:flex;
      gap: 12px;
    }

    .colab-df-convert {
      background-color: #E8F0FE;
      border: none;
      border-radius: 50%;
      cursor: pointer;
      display: none;
      fill: #1967D2;
      height: 32px;
      padding: 0 0 0 0;
      width: 32px;
    }

    .colab-df-convert:hover {
      background-color: #E2EBFA;
      box-shadow: 0px 1px 2px rgba(60, 64, 67, 0.3), 0px 1px 3px 1px rgba(60, 64, 67, 0.15);
      fill: #174EA6;
    }

    .colab-df-buttons div {
      margin-bottom: 4px;
    }

    [theme=dark] .colab-df-convert {
      background-color: #3B4455;
      fill: #D2E3FC;
    }

    [theme=dark] .colab-df-convert:hover {
      background-color: #434B5C;
      box-shadow: 0px 1px 3px 1px rgba(0, 0, 0, 0.15);
      filter: drop-shadow(0px 1px 2px rgba(0, 0, 0, 0.3));
      fill: #FFFFFF;
    }
  

    
      const buttonEl =
        document.querySelector('#df-328dc7aa-041e-423c-ba4b-026a6914fdc8 button.colab-df-convert');
      buttonEl.style.display =
        google.colab.kernel.accessAllowed ? 'block' : 'none';

      async function convertToInteractive(key) {
        const element = document.querySelector('#df-328dc7aa-041e-423c-ba4b-026a6914fdc8');
        const dataTable =
          await google.colab.kernel.invokeFunction('convertToInteractive',
                                                    [key], {});
        if (!dataTable) return;

        const docLinkHtml = 'Like what you see? Visit the ' +
          '<a target="_blank" href=https://colab.research.google.com/notebooks/data_table.ipynb>data table notebook</a>'
          + ' to learn more about interactive tables.';
        element.innerHTML = '';
        dataTable['output_type'] = 'display_data';
        await google.colab.output.renderOutput(dataTable, element);
        const docLink = document.createElement('div');
        docLink.innerHTML = docLinkHtml;
        element.appendChild(docLink);
      }
    
  


  
    
      .colab-df-generate {
        background-color: #E8F0FE;
        border: none;
        border-radius: 50%;
        cursor: pointer;
        display: none;
        fill: #1967D2;
        height: 32px;
        padding: 0 0 0 0;
        width: 32px;
      }

      .colab-df-generate:hover {
        background-color: #E2EBFA;
        box-shadow: 0px 1px 2px rgba(60, 64, 67, 0.3), 0px 1px 3px 1px rgba(60, 64, 67, 0.15);
        fill: #174EA6;
      }

      [theme=dark] .colab-df-generate {
        background-color: #3B4455;
        fill: #D2E3FC;
      }

      [theme=dark] .colab-df-generate:hover {
        background-color: #434B5C;
        box-shadow: 0px 1px 3px 1px rgba(0, 0, 0, 0.15);
        filter: drop-shadow(0px 1px 2px rgba(0, 0, 0, 0.3));
        fill: #FFFFFF;
      }
    
    

  
    
  
    
    
      (() => {
      const buttonEl =
        document.querySelector('#id_f6a1bacd-08de-48b7-978a-cb12b0261dea button.colab-df-generate');
      buttonEl.style.display =
        google.colab.kernel.accessAllowed ? 'block' : 'none';

      buttonEl.onclick = () => {
        google.colab.notebook.generateWithVariable('counts');
      }
      })();
    
  

    
  

  
    

    .dataframe tbody tr th:only-of-type {
        vertical-align: middle;
    }

    .dataframe tbody tr th {
        vertical-align: top;
    }

    .dataframe thead th {
        text-align: right;
    }


  
    
      
      Date
      n_rows
      n_code4
      n_notrade
    
  
  
    
      0
      2021-02-01
      4086
      4084
      103.0
    
    
      1
      2021-02-02
      4086
      4084
      108.0
    
    
      2
      2021-02-03
      4086
      4084
      99.0
    
    
      3
      2021-02-04
      4085
      4084
      115.0
    
    
      4
      2021-02-05
      4086
      4085
      104.0
    
  


    

  
    

  
    
  
    

  
    .colab-df-container {
      display:flex;
      gap: 12px;
    }

    .colab-df-convert {
      background-color: #E8F0FE;
      border: none;
      border-radius: 50%;
      cursor: pointer;
      display: none;
      fill: #1967D2;
      height: 32px;
      padding: 0 0 0 0;
      width: 32px;
    }

    .colab-df-convert:hover {
      background-color: #E2EBFA;
      box-shadow: 0px 1px 2px rgba(60, 64, 67, 0.3), 0px 1px 3px 1px rgba(60, 64, 67, 0.15);
      fill: #174EA6;
    }

    .colab-df-buttons div {
      margin-bottom: 4px;
    }

    [theme=dark] .colab-df-convert {
      background-color: #3B4455;
      fill: #D2E3FC;
    }

    [theme=dark] .colab-df-convert:hover {
      background-color: #434B5C;
      box-shadow: 0px 1px 3px 1px rgba(0, 0, 0, 0.15);
      filter: drop-shadow(0px 1px 2px rgba(0, 0, 0, 0.3));
      fill: #FFFFFF;
    }
  

    
      const buttonEl =
        document.querySelector('#df-b3f60256-2f00-4ace-9f23-e9b0d03e7f5d button.colab-df-convert');
      buttonEl.style.display =
        google.colab.kernel.accessAllowed ? 'block' : 'none';

      async function convertToInteractive(key) {
        const element = document.querySelector('#df-b3f60256-2f00-4ace-9f23-e9b0d03e7f5d');
        const dataTable =
          await google.colab.kernel.invokeFunction('convertToInteractive',
                                                    [key], {});
        if (!dataTable) return;

        const docLinkHtml = 'Like what you see? Visit the ' +
          '<a target="_blank" href=https://colab.research.google.com/notebooks/data_table.ipynb>data table notebook</a>'
          + ' to learn more about interactive tables.';
        element.innerHTML = '';
        dataTable['output_type'] = 'display_data';
        await google.colab.output.renderOutput(dataTable, element);
        const docLink = document.createElement('div');
        docLink.innerHTML = docLinkHtml;
        element.appendChild(docLink);
      }
    
  


    
  

  
    

    .dataframe tbody tr th:only-of-type {
        vertical-align: middle;
    }

    .dataframe tbody tr th {
        vertical-align: top;
    }

    .dataframe thead th {
        text-align: right;
    }


  
    
      
      Date
      n_rows
      n_code4
      n_notrade
    
  
  
    
      1218
      2026-01-26
      4438
      4432
      183.0
    
    
      1219
      2026-01-27
      4437
      4431
      206.0
    
    
      1220
      2026-01-28
      4437
      4431
      202.0
    
    
      1221
      2026-01-29
      4435
      4429
      214.0
    
    
      1222
      2026-01-30
      4435
      4429
      195.0
    
  


    

  
    

  
    
  
    

  
    .colab-df-container {
      display:flex;
      gap: 12px;
    }

    .colab-df-convert {
      background-color: #E8F0FE;
      border: none;
      border-radius: 50%;
      cursor: pointer;
      display: none;
      fill: #1967D2;
      height: 32px;
      padding: 0 0 0 0;
      width: 32px;
    }

    .colab-df-convert:hover {
      background-color: #E2EBFA;
      box-shadow: 0px 1px 2px rgba(60, 64, 67, 0.3), 0px 1px 3px 1px rgba(60, 64, 67, 0.15);
      fill: #174EA6;
    }

    .colab-df-buttons div {
      margin-bottom: 4px;
    }

    [theme=dark] .colab-df-convert {
      background-color: #3B4455;
      fill: #D2E3FC;
    }

    [theme=dark] .colab-df-convert:hover {
      background-color: #434B5C;
      box-shadow: 0px 1px 3px 1px rgba(0, 0, 0, 0.15);
      filter: drop-shadow(0px 1px 2px rgba(0, 0, 0, 0.3));
      fill: #FFFFFF;
    }
  

    
      const buttonEl =
        document.querySelector('#df-9d4d16c6-470b-4310-9ab4-d3f58c973bef button.colab-df-convert');
      buttonEl.style.display =
        google.colab.kernel.accessAllowed ? 'block' : 'none';

      async function convertToInteractive(key) {
        const element = document.querySelector('#df-9d4d16c6-470b-4310-9ab4-d3f58c973bef');
        const dataTable =
          await google.colab.kernel.invokeFunction('convertToInteractive',
                                                    [key], {});
        if (!dataTable) return;

        const docLinkHtml = 'Like what you see? Visit the ' +
          '<a target="_blank" href=https://colab.research.google.com/notebooks/data_table.ipynb>data table notebook</a>'
          + ' to learn more about interactive tables.';
        element.innerHTML = '';
        dataTable['output_type'] = 'display_data';
        await google.colab.output.renderOutput(dataTable, element);
        const docLink = document.createElement('div');
        docLink.innerHTML = docLinkHtml;
        element.appendChild(docLink);
      }
    
  


    
  
median n_code4 = 4277.0

  
    

    .dataframe tbody tr th:only-of-type {
        vertical-align: middle;
    }

    .dataframe tbody tr th {
        vertical-align: top;
    }

    .dataframe thead th {
        text-align: right;
    }


  
    
      
      Date
      n_rows
      n_code4
      n_notrade
    
  
  
  


    

  
    

  
    
  
    

  
    .colab-df-container {
      display:flex;
      gap: 12px;
    }

    .colab-df-convert {
      background-color: #E8F0FE;
      border: none;
      border-radius: 50%;
      cursor: pointer;
      display: none;
      fill: #1967D2;
      height: 32px;
      padding: 0 0 0 0;
      width: 32px;
    }

    .colab-df-convert:hover {
      background-color: #E2EBFA;
      box-shadow: 0px 1px 2px rgba(60, 64, 67, 0.3), 0px 1px 3px 1px rgba(60, 64, 67, 0.15);
      fill: #174EA6;
    }

    .colab-df-buttons div {
      margin-bottom: 4px;
    }

    [theme=dark] .colab-df-convert {
      background-color: #3B4455;
      fill: #D2E3FC;
    }

    [theme=dark] .colab-df-convert:hover {
      background-color: #434B5C;
      box-shadow: 0px 1px 3px 1px rgba(0, 0, 0, 0.15);
      filter: drop-shadow(0px 1px 2px rgba(0, 0, 0, 0.3));
      fill: #FFFFFF;
    }
  

    
      const buttonEl =
        document.querySelector('#df-a11d9918-5de5-46cf-9423-0113d4ec5f1d button.colab-df-convert');
      buttonEl.style.display =
        google.colab.kernel.accessAllowed ? 'block' : 'none';

      async function convertToInteractive(key) {
        const element = document.querySelector('#df-a11d9918-5de5-46cf-9423-0113d4ec5f1d');
        const dataTable =
          await google.colab.kernel.invokeFunction('convertToInteractive',
                                                    [key], {});
        if (!dataTable) return;

        const docLinkHtml = 'Like what you see? Visit the ' +
          '<a target="_blank" href=https://colab.research.google.com/notebooks/data_table.ipynb>data table notebook</a>'
          + ' to learn more about interactive tables.';
        element.innerHTML = '';
        dataTable['output_type'] = 'display_data';
        await google.colab.output.renderOutput(dataTable, element);
        const docLink = document.createElement('div');
        docLink.innerHTML = docLinkHtml;
        element.appendChild(docLink);
      }
    
  


    
  

  
    

    .dataframe tbody tr th:only-of-type {
        vertical-align: middle;
    }

    .dataframe tbody tr th {
        vertical-align: top;
    }

    .dataframe thead th {
        text-align: right;
    }


  
    
      
      Date
      Code4
      n
    
  
  
    
      0
      2024-11-20
      9434
      3
    
    
      1
      2025-03-28
      9434
      3
    
    
      2
      2024-11-25
      9434
      3
    
    
      3
      2025-06-17
      9434
      3
    
    
      4
      2025-04-02
      9434
      3
    
    
      5
      2024-12-06
      9434
      3
    
    
      6
      2024-12-03
      9434
      3
    
    
      7
      2025-07-01
      9434
      3
    
    
      8
      2025-06-20
      9434
      3
    
    
      9
      2025-04-17
      9434
      3
    
    
      10
      2025-04-09
      9434
      3
    
    
      11
      2024-12-16
      9434
      3
    
    
      12
      2024-12-11
      9434
      3
    
    
      13
      2024-11-26
      9434
      3
    
    
      14
      2025-03-27
      9434
      3
    
    
      15
      2025-07-11
      9434
      3
    
    
      16
      2025-07-07
      9434
      3
    
    
      17
      2025-06-23
      9434
      3
    
    
      18
      2025-06-30
      9434
      3
    
    
      19
      2025-04-24
      9434
      3
    
    
      20
      2025-04-22
      9434
      3
    
    
      21
      2025-04-03
      9434
      3
    
    
      22
      2025-06-13
      9434
      3
    
    
      23
      2024-12-18
      9434
      3
    
    
      24
      2025-03-25
      9434
      3
    
    
      25
      2024-12-10
      9434
      3
    
    
      26
      2025-03-26
      9434
      3
    
    
      27
      2024-11-28
      9434
      3
    
    
      28
      2024-11-29
      9434
      3
    
    
      29
      2024-11-22
      9434
      3
    
    
      30
      2025-09-08
      9434
      3
    
    
      31
      2025-07-16
      9434
      3
    
    
      32
      2025-07-17
      9434
      3
    
    
      33
      2025-07-03
      9434
      3
    
    
      34
      2025-09-01
      9434
      3
    
    
      35
      2025-06-25
      9434
      3
    
    
      36
      2025-06-26
      9434
      3
    
    
      37
      2025-06-18
      9434
      3
    
    
      38
      2025-09-03
      9434
      3
    
    
      39
      2025-04-25
      9434
      3
    
    
      40
      2025-04-28
      9434
      3
    
    
      41
      2025-04-18
      9434
      3
    
    
      42
      2025-06-12
      9434
      3
    
    
      43
      2025-04-07
      9434
      3
    
    
      44
      2025-04-08
      9434
      3
    
    
      45
      2025-04-01
      9434
      3
    
    
      46
      2025-09-04
      9434
      3
    
    
      47
      2025-03-21
      9434
      3
    
    
      48
      2025-03-24
      9434
      3
    
    
      49
      2025-09-09
      9434
      3
    
  


    

  
    

  
    
  
    

  
    .colab-df-container {
      display:flex;
      gap: 12px;
    }

    .colab-df-convert {
      background-color: #E8F0FE;
      border: none;
      border-radius: 50%;
      cursor: pointer;
      display: none;
      fill: #1967D2;
      height: 32px;
      padding: 0 0 0 0;
      width: 32px;
    }

    .colab-df-convert:hover {
      background-color: #E2EBFA;
      box-shadow: 0px 1px 2px rgba(60, 64, 67, 0.3), 0px 1px 3px 1px rgba(60, 64, 67, 0.15);
      fill: #174EA6;
    }

    .colab-df-buttons div {
      margin-bottom: 4px;
    }

    [theme=dark] .colab-df-convert {
      background-color: #3B4455;
      fill: #D2E3FC;
    }

    [theme=dark] .colab-df-convert:hover {
      background-color: #434B5C;
      box-shadow: 0px 1px 3px 1px rgba(0, 0, 0, 0.15);
      filter: drop-shadow(0px 1px 2px rgba(0, 0, 0, 0.3));
      fill: #FFFFFF;
    }
  

    
      const buttonEl =
        document.querySelector('#df-27ed6210-e17f-464f-a7b9-6d1c6712ff92 button.colab-df-convert');
      buttonEl.style.display =
        google.colab.kernel.accessAllowed ? 'block' : 'none';

      async function convertToInteractive(key) {
        const element = document.querySelector('#df-27ed6210-e17f-464f-a7b9-6d1c6712ff92');
        const dataTable =
          await google.colab.kernel.invokeFunction('convertToInteractive',
                                                    [key], {});
        if (!dataTable) return;

        const docLinkHtml = 'Like what you see? Visit the ' +
          '<a target="_blank" href=https://colab.research.google.com/notebooks/data_table.ipynb>data table notebook</a>'
          + ' to learn more about interactive tables.';
        element.innerHTML = '';
        dataTable['output_type'] = 'display_data';
        await google.colab.output.renderOutput(dataTable, element);
        const docLink = document.createElement('div');
        docLink.innerHTML = docLinkHtml;
        element.appendChild(docLink);
      }
    
  


  
    
      .colab-df-generate {
        background-color: #E8F0FE;
        border: none;
        border-radius: 50%;
        cursor: pointer;
        display: none;
        fill: #1967D2;
        height: 32px;
        padding: 0 0 0 0;
        width: 32px;
      }

      .colab-df-generate:hover {
        background-color: #E2EBFA;
        box-shadow: 0px 1px 2px rgba(60, 64, 67, 0.3), 0px 1px 3px 1px rgba(60, 64, 67, 0.15);
        fill: #174EA6;
      }

      [theme=dark] .colab-df-generate {
        background-color: #3B4455;
        fill: #D2E3FC;
      }

      [theme=dark] .colab-df-generate:hover {
        background-color: #434B5C;
        box-shadow: 0px 1px 3px 1px rgba(0, 0, 0, 0.15);
        filter: drop-shadow(0px 1px 2px rgba(0, 0, 0, 0.3));
        fill: #FFFFFF;
      }
    
    

  
    
  
    
    
      (() => {
      const buttonEl =
        document.querySelector('#id_773c0a0b-4418-4a74-96c4-b3137d27fe26 button.colab-df-generate');
      buttonEl.style.display =
        google.colab.kernel.accessAllowed ? 'block' : 'none';

      buttonEl.onclick = () => {
        google.colab.notebook.generateWithVariable('dups');
      }
      })();
    
  

    
  

  
    

    .dataframe tbody tr th:only-of-type {
        vertical-align: middle;
    }

    .dataframe tbody tr th {
        vertical-align: top;
    }

    .dataframe thead th {
        text-align: right;
    }


  
    
      
      Date
      Code4
      Code
      Open
      High
      Low
      Close
      Volume
      TurnoverValue
      IsNoTrade
    
  
  
    
      0
      2026-01-30
      1301
      13010
      5100.0
      5140.0
      5060.0
      5140.0
      42100.0
      2.148000e+08
      False
    
    
      1
      2026-01-30
      1305
      13050
      3776.0
      3792.0
      3753.0
      3785.0
      37560.0
      1.420538e+08
      False
    
    
      2
      2026-01-30
      1306
      13060
      3737.0
      3752.0
      3712.0
      3744.0
      1982240.0
      7.413928e+09
      False
    
    
      3
      2026-01-30
      1308
      13080
      3690.0
      3707.0
      3669.0
      3706.0
      455444.0
      1.681818e+09
      False
    
    
      4
      2026-01-30
      1309
      13090
      55200.0
      55500.0
      54420.0
      54960.0
      101.0
      5.540230e+06
      False
    
    
      5
      2026-01-30
      130A
      130A0
      482.0
      496.0
      478.0
      493.0
      89000.0
      4.337910e+07
      False
    
    
      6
      2026-01-30
      1311
      13110
      1860.0
      1872.0
      1852.0
      1870.0
      14013.0
      2.614496e+07
      False
    
    
      7
      2026-01-30
      1320
      13200
      55150.0
      55450.0
      54810.0
      55170.0
      26711.0
      1.473082e+09
      False
    
    
      8
      2026-01-30
      1321
      13210
      55350.0
      55650.0
      55010.0
      55390.0
      277576.0
      1.536856e+10
      False
    
    
      9
      2026-01-30
      1322
      13220
      11290.0
      11290.0
      10985.0
      11050.0
      750.0
      8.318230e+06
      False
    
    
      10
      2026-01-30
      1325
      13250
      308.0
      308.0
      297.0
      299.3
      171870.0
      5.219379e+07
      False
    
    
      11
      2026-01-30
      1326
      13260
      76650.0
      76840.0
      72350.0
      73120.0
      172244.0
      1.283279e+10
      False
    
    
      12
      2026-01-30
      1328
      13280
      19790.0
      19845.0
      18700.0
      18895.0
      409450.0
      7.891583e+09
      False
    
    
      13
      2026-01-30
      1329
      13290
      5552.0
      5578.0
      5512.0
      5546.0
      418116.0
      2.319138e+09
      False
    
    
      14
      2026-01-30
      1330
      13300
      55410.0
      55710.0
      55070.0
      55460.0
      18477.0
      1.024480e+09
      False
    
    
      15
      2026-01-30
      1332
      13320
      1276.0
      1298.5
      1273.0
      1295.0
      1504500.0
      1.940484e+09
      False
    
    
      16
      2026-01-30
      1333
      13330
      1391.0
      1397.5
      1385.5
      1388.5
      467800.0
      6.503381e+08
      False
    
    
      17
      2026-01-30
      133A
      133A0
      1034.0
      1040.0
      1033.0
      1040.0
      71523.0
      7.417632e+07
      False
    
    
      18
      2026-01-30
      1343
      13430
      2167.5
      2174.0
      2151.5
      2151.5
      1875680.0
      4.051262e+09
      False
    
    
      19
      2026-01-30
      1345
      13450
      2033.5
      2033.5
      2012.0
      2014.5
      58200.0
      1.174990e+08
      False
    
  


    

  
    

  
    
  
    

  
    .colab-df-container {
      display:flex;
      gap: 12px;
    }

    .colab-df-convert {
      background-color: #E8F0FE;
      border: none;
      border-radius: 50%;
      cursor: pointer;
      display: none;
      fill: #1967D2;
      height: 32px;
      padding: 0 0 0 0;
      width: 32px;
    }

    .colab-df-convert:hover {
      background-color: #E2EBFA;
      box-shadow: 0px 1px 2px rgba(60, 64, 67, 0.3), 0px 1px 3px 1px rgba(60, 64, 67, 0.15);
      fill: #174EA6;
    }

    .colab-df-buttons div {
      margin-bottom: 4px;
    }

    [theme=dark] .colab-df-convert {
      background-color: #3B4455;
      fill: #D2E3FC;
    }

    [theme=dark] .colab-df-convert:hover {
      background-color: #434B5C;
      box-shadow: 0px 1px 3px 1px rgba(0, 0, 0, 0.15);
      filter: drop-shadow(0px 1px 2px rgba(0, 0, 0, 0.3));
      fill: #FFFFFF;
    }
  

    
      const buttonEl =
        document.querySelector('#df-a2d8a485-3a9e-4bf0-a19c-6e80dab89982 button.colab-df-convert');
      buttonEl.style.display =
        google.colab.kernel.accessAllowed ? 'block' : 'none';

      async function convertToInteractive(key) {
        const element = document.querySelector('#df-a2d8a485-3a9e-4bf0-a19c-6e80dab89982');
        const dataTable =
          await google.colab.kernel.invokeFunction('convertToInteractive',
                                                    [key], {});
        if (!dataTable) return;

        const docLinkHtml = 'Like what you see? Visit the ' +
          '<a target="_blank" href=https://colab.research.google.com/notebooks/data_table.ipynb>data table notebook</a>'
          + ' to learn more about interactive tables.';
        element.innerHTML = '';
        dataTable['output_type'] = 'display_data';
        await google.colab.output.renderOutput(dataTable, element);
        const docLink = document.createElement('div');
        docLink.innerHTML = docLinkHtml;
        element.appendChild(docLink);
      }
    
  


  
    
      .colab-df-generate {
        background-color: #E8F0FE;
        border: none;
        border-radius: 50%;
        cursor: pointer;
        display: none;
        fill: #1967D2;
        height: 32px;
        padding: 0 0 0 0;
        width: 32px;
      }

      .colab-df-generate:hover {
        background-color: #E2EBFA;
        box-shadow: 0px 1px 2px rgba(60, 64, 67, 0.3), 0px 1px 3px 1px rgba(60, 64, 67, 0.15);
        fill: #174EA6;
      }

      [theme=dark] .colab-df-generate {
        background-color: #3B4455;
        fill: #D2E3FC;
      }

      [theme=dark] .colab-df-generate:hover {
        background-color: #434B5C;
        box-shadow: 0px 1px 3px 1px rgba(0, 0, 0, 0.15);
        filter: drop-shadow(0px 1px 2px rgba(0, 0, 0, 0.3));
        fill: #FFFFFF;
      }
    
    

  
    
  
    
    
      (() => {
      const buttonEl =
        document.querySelector('#id_5093e97e-3824-4c5c-a643-1108fd244469 button.colab-df-generate');
      buttonEl.style.display =
        google.colab.kernel.accessAllowed ? 'block' : 'none';

      buttonEl.onclick = () => {
        google.colab.notebook.generateWithVariable('sample');
      }
      })();
    
  

    
  
DONE

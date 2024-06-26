import React from 'react';
import ReactDOM from 'react-dom/client';
import { BrowserRouter as Router } from 'react-router-dom';
import { ChainId, ThirdwebProvider } from '@thirdweb-dev/react';

import { StateContextProvider } from './context';
import App from './App';
import './index.css';

const customChain = {
  name: "Vitruveo Mainnet",
  chainId: 1490,
  rpc: ["https://rpc.vitruveo.xyz"], // Vervang door de daadwerkelijke RPC-URL
  nativeCurrency: {
    name: "Vitruveo Mainnet",
    symbol: "VTRU",
    decimals: 18
  },
  explorers: [
    {
      name: "Vitruveo Explorer",
      url: "https://explorer.vitruveo.xyz", // Vervang door de daadwerkelijke explorer-URL
    }
  ],
};

const root = ReactDOM.createRoot(document.getElementById('root'));

root.render(
  <ThirdwebProvider 
    supportedChains={[customChain]} 
    activeChain={1490} 
    clientId="a3311959362ef220f7eaa27b0833d620"
  > 
    <Router>
      <StateContextProvider>
        <App />
      </StateContextProvider>
    </Router>
  </ThirdwebProvider> 
);

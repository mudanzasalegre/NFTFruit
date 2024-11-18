// src/App.js

import React from 'react';
import { BrowserRouter as Router, Route, Routes } from 'react-router-dom';
import { ChakraProvider, Box } from '@chakra-ui/react';
import {
  RainbowKitProvider,
  ConnectButton,
  getDefaultWallets,
} from '@rainbow-me/rainbowkit';
import { WagmiConfig, createConfig } from 'wagmi';
import { mainnet, polygon } from '@wagmi/core/chains';
import { publicProvider } from '@wagmi/core/providers/public';

import Home from './pages/Home';
import AdminDashboard from './pages/Admin/AdminDashboard';
import ProducerDashboard from './pages/Producer/ProducerDashboard';
import Marketplace from './pages/Marketplace/Marketplace';
import Header from './components/Header';

import '@rainbow-me/rainbowkit/styles.css';

// Configurar RainbowKit y Wagmi
const { chains, provider } = createConfig({
  autoConnect: true,
  connectors: getDefaultWallets({
    appName: 'Agricultura DApp',
    chains: [mainnet, polygon],
    projectId: 'YOUR_PROJECT_ID', // Reemplaza con tu propio Project ID
  }).connectors,
  publicProvider: publicProvider(),
});

const App = () => {
  return (
    <ChakraProvider>
      <WagmiConfig config={provider}>
        <RainbowKitProvider chains={chains}>
          <Router>
            <Header />
            <Box p={4}>
              {/* Conectar Wallet */}
              <ConnectButton label="Conectar Wallet" />

              {/* Definir rutas y páginas */}
              <Routes>
                <Route path="/" element={<Home />} />
                <Route path="/admin" element={<AdminDashboard />} />
                <Route path="/producer" element={<ProducerDashboard />} />
                <Route path="/marketplace" element={<Marketplace />} />
              </Routes>
            </Box>
          </Router>
        </RainbowKitProvider>
      </WagmiConfig>
    </ChakraProvider>
  );
};

export default App;

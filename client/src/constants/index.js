import { createCampaign, dashboard, logout, payment, profile, withdraw } from '../assets';

export const navlinks = [
  {
    name: 'Home',
    imgUrl: dashboard,
    link: '/',
    id: 0
  },
  {
    name: 'Start campaign',
    imgUrl: createCampaign,
    link: '/create-campaign',
    id: 1
  },

  {
    name: 'Profile',
    imgUrl: profile,
    link: '/profile',
    id: 4
  },

];

!=====================================================================
!
!          S p e c f e m 3 D  G l o b e  V e r s i o n  7 . 0
!          --------------------------------------------------
!
!     Main historical authors: Dimitri Komatitsch and Jeroen Tromp
!                        Princeton University, USA
!                and CNRS / University of Marseille, France
!                 (there are currently many more authors!)
! (c) Princeton University and CNRS / University of Marseille, April 2014
!
! This program is free software; you can redistribute it and/or modify
! it under the terms of the GNU General Public License as published by
! the Free Software Foundation; either version 2 of the License, or
! (at your option) any later version.
!
! This program is distributed in the hope that it will be useful,
! but WITHOUT ANY WARRANTY; without even the implied warranty of
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
! GNU General Public License for more details.
!
! You should have received a copy of the GNU General Public License along
! with this program; if not, write to the Free Software Foundation, Inc.,
! 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
!
!=====================================================================

!==============================================================================
! Copyright 2015 ASDF developers
!
! Licensed under the Apache License, Version 2.0 (the "License");
! you may not use this file except in compliance with the License.
! You may obtain a copy of the License at
!
!    http://www.apache.org/licenses/LICENSE-2.0
!
! Unless required by applicable law or agreed to in writing, software
! distributed under the License is distributed on an "AS IS" BASIS,
! WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
! See the License for the specific language governing permissions and
! limitations under the License.
!==============================================================================

!> Initializes the data structure for ASDF
!! \param asdf_container The ASDF data structure
!! \param total_seismos_local The number of records on the local processor
subroutine init_asdf_data(asdf_container,total_seismos_local)

  use asdf_data
  use specfem_par, only : event_name_SAC,myrank

  ! Parameters
  type(asdf_event),intent(inout) :: asdf_container
  integer,intent(in) :: total_seismos_local

  ! Variables
  integer :: ier

  asdf_container%event = trim(event_name_SAC)

  allocate (asdf_container%receiver_name_array(total_seismos_local), &
            STAT=ier)
  if (ier /= 0) call exit_MPI (myrank, 'Allocate failed.')
  allocate (asdf_container%network_array(total_seismos_local), STAT=ier)
  if (ier /= 0) call exit_MPI (myrank, 'Allocate failed.')
  allocate (asdf_container%component_array(total_seismos_local), STAT=ier)
  if (ier /= 0) call exit_MPI (myrank, 'Allocate failed.')
  allocate (asdf_container%records(total_seismos_local), STAT=ier)
  if (ier /= 0) call exit_MPI (myrank, 'Allocate failed.')

end subroutine init_asdf_data

!
!-------------------------------------------------------------------------------------------------
!

!> Stores the records into the ASDF structure
!! \param asdf_container The ASDF data structure
!! \param seismogram_tmp The current seismogram to store
!! \param irec_local The local index of the receivers on the local processor
!! \param irec The global index of the receiver
!! \param chn The broadband channel simulated
!! \param iorientation The recorded seismogram's orientation direction
!! \param phi The angle used for calculating azimuth and incident angle
subroutine store_asdf_data(asdf_container, seismogram_tmp, irec_local, &
                           irec, chn, iorientation, phi)

  use asdf_data
  use specfem_par,only: &
    station_name,network_name,stlat,stlon,stele,stbur, &
    DT,t0, seismo_offset,seismo_current, NTSTEP_BETWEEN_OUTPUT_SEISMOS, &
    yr=>yr_SAC,jda=>jda_SAC,ho=>ho_SAC,mi=>mi_SAC,sec=>sec_SAC, &
    tshift_cmt=>t_cmt_SAC, &
    cmt_lat=>cmt_lat_SAC,cmt_lon=>cmt_lon_SAC, &
    cmt_depth=>cmt_depth_SAC

  use specfem_par, only: myrank
  use constants

  implicit none

  ! Parameters
  type(asdf_event),intent(inout) :: asdf_container
  character(len=4),intent(in) :: chn
  integer,intent(in) :: irec_local, irec
  real(kind=CUSTOM_REAL),dimension(5,NTSTEP_BETWEEN_OUTPUT_SEISMOS),intent(in) :: seismogram_tmp
  integer,intent(in) :: iorientation
  double precision,intent(in) :: phi
  ! local Variables
  integer :: length_station_name, length_network_name
  integer :: ier, i

  ! trace index
  i = (irec_local-1)*(3) + (iorientation)

  length_station_name = len_trim(station_name(irec))
  length_network_name = len_trim(network_name(irec))
  asdf_container%receiver_name_array(i) = station_name(irec)(1:length_station_name)
  asdf_container%network_array(i) = network_name(irec)(1:length_network_name)
  asdf_container%component_array(i) = chn

  allocate (asdf_container%records(i)%record(seismo_current), STAT=ier)
  if (ier /= 0) call exit_MPI (myrank, 'Allocating ASDF container failed.')
  asdf_container%records(i)%record(1:seismo_current) = seismogram_tmp(iorientation, 1:seismo_current)

end subroutine store_asdf_data

!
!-------------------------------------------------------------------------------------------------
!

!> Closes the ASDF data structure by deallocating all arrays
!! \param asdf_container The ASDF data structure
!! \param total_seismos_local The number of seismograms on the local processor
subroutine close_asdf_data(asdf_container, total_seismos_local)

  use asdf_data
  ! Parameters
  type(asdf_event),intent(inout) :: asdf_container
  integer,intent(in) :: total_seismos_local
  !Variables
  integer :: i

  do i = 1, total_seismos_local
    deallocate(asdf_container%records(i)%record)
  enddo
  deallocate (asdf_container%receiver_name_array)
  deallocate (asdf_container%network_array)
  deallocate (asdf_container%component_array)

end subroutine close_asdf_data

!
!-------------------------------------------------------------------------------------------------
!

!> Writes the ASDF data structure to the file
!! \param asdf_container The ASDF data structure
subroutine write_asdf(asdf_container)

  use asdf_data
  use iso_c_binding
  use specfem_par

  implicit none
  ! Parameters
  type(asdf_event),intent(inout) :: asdf_container

  integer, parameter :: MAX_STRING_LENGTH = 256

  character(len=MAX_STRING_LENGTH) :: filename

  !--- Data to be written to the ASDF file
  character(len=MAX_STRING_LENGTH) :: event_name
  character(len=MAX_STRING_LENGTH) :: station
  character(len=MAX_STRING_LENGTH) :: quakeml
  character(len=MAX_STRING_LENGTH) :: station_xml

  integer :: num_stations, num_channels_per_station
  integer :: num_waveforms  ! == num_stations * num_channels_per_station
  ! The number of channels per station is constant, as in SPECFEM

  integer :: start_time, nsamples  ! constant, as in SPECFEM
  double precision :: sampling_rate  ! idem

  ! Network names and station names are two different beast, as in SPECFEM
  ! network_names(i) is related to station_names(i)
  character(len=MAX_STRING_LENGTH), dimension(:), allocatable :: networks_names
  character(len=MAX_STRING_LENGTH), dimension(:), allocatable :: stations_names

  ! data. dimension = nsamples * num_channels_per_station * num_stations
  real, dimension(:, :, :), allocatable :: waveforms

  !-- ASDF variables 
  !   These variables are used to know where further writes should be done.
  !   They have to be cleaned as soon as they become useless
  integer :: file_id   ! HDF5 file id, also root group "/"
  integer :: waveforms_grp  ! Group "/Waveforms/" 
  integer, dimension(:), allocatable :: station_grps
  integer, dimension(:, :, :), allocatable :: data_ids

  !--- MPI variables
  integer :: mysize, comm
  !--- Loop variables
  integer :: i, j, k
  !--- Error variable
  integer :: ier

  !--- 'allgather' arrays. Variables that needs to be known by everyone in
  !    order to define ASDF groups and datasets or write them as attributes.
  integer, dimension(:), allocatable :: num_stations_gather
  integer :: max_num_stations_gather
  character(len=MAX_STRING_LENGTH), dimension(:,:), allocatable :: &
      station_names_gather, network_names_gather
  integer, dimension(:,:), allocatable :: station_grps_gather
  integer, dimension(:), allocatable :: displs, rcounts

  ! temporary name built from network, station and channel names.
  character(len=MAX_STRING_LENGTH) :: waveform_name

  ! alias mpi communicator for ADIOS
  call world_duplicate(comm)
  call world_size(mysize)

  !--------------------------------------------------------
  ! Setup data on each process.
  !--------------------------------------------------------

  filename = "synthetic.h5"
  event_name = trim(event_name_SAC)
  quakeml = "<quakeml>"
  station_xml = "<station_xml>"

  num_stations = nrec_local
  num_channels_per_station = 3
  sampling_rate = DT
  nsamples = seismo_current
  start_time = seismo_offset*DT-t0+t_cmt_SAC
  num_waveforms = num_stations * num_channels_per_station

  allocate(networks_names(num_stations), stat=ier)
  allocate(stations_names(num_stations), stat=ier)
  allocate(waveforms(nsamples, num_channels_per_station, num_stations), &
           stat=ier)

  do i = 1, num_stations
   write(networks_names(i), '(a)') asdf_container%network_array(i)
   write(stations_names(i), '(a)') asdf_container%receiver_name_array(i)
  enddo

  ! -- We do not care about seeding.
  call random_number(waveforms)

  !--------------------------------------------------------
  ! ASDF variables
  !--------------------------------------------------------
  ! Find how many stations are managed by each allgatheress
  allocate(num_stations_gather(mysize))
  call all_gather_all_i(num_stations, num_stations_gather, mysize)
  ! find the largest number of stations per allgatheress
  max_num_stations_gather = maxval(num_stations_gather)

  allocate(displs(mysize))
  allocate(rcounts(mysize))

  ! Everyone should know about each and every station name
  allocate(station_names_gather(max_num_stations_gather, mysize))
  allocate(network_names_gather(max_num_stations_gather, mysize))

  ! The number of stations is not constant across processes
  do i = 1, mysize
    displs(i) = (i-1) * max_num_stations_gather * max_string_length
    rcounts(i) = num_stations_gather(i) * max_string_length
  enddo
  call all_gather_all_ch(stations_names, &
                         num_stations * MAX_STRING_LENGTH, &
                         station_names_gather, &
                         rcounts, &
                         displs, &
                         max_num_stations_gather, &
                         MAX_STRING_LENGTH, &
                         mysize)
  call all_gather_all_ch(networks_names, &
                         num_stations * MAX_STRING_LENGTH, &
                         network_names_gather, &
                         rcounts, &
                         displs, &
                         max_num_stations_gather, &
                         MAX_STRING_LENGTH, &
                         mysize)
  deallocate(displs)
  deallocate(rcounts)

  allocate(station_grps_gather(max_num_stations_gather, mysize))

  allocate(data_ids(num_channels_per_station, &
                    max_num_stations_gather, &
                    mysize))

  !--------------------------------------------------------
  ! write ASDF 
  !--------------------------------------------------------
print *, "initializing ASDF"
  call ASDF_initialize_hdf5_f(ier);
  call ASDF_create_new_file_f(trim(filename), comm, file_id)

  call ASDF_write_string_attribute_f(file_id, "file_format" // C_NULL_CHAR, &
                                     "ASDF" // C_NULL_CHAR, ier)
  call ASDF_write_string_attribute_f(file_id, "file_version" // C_NULL_CHAR, &
                                     "0.0.1.b" // C_NULL_CHAR, ier)

  call ASDF_write_auxiliary_data_f(file_id, ier)
  call ASDF_write_provenance_data_f(file_id, ier)
  call ASDF_write_quakeml_f(file_id, trim(quakeml), ier)

  call ASDF_create_waveforms_group_f(file_id, waveforms_grp)

  print *, "defining waveforms"
  do k = 1, mysize
    do j = 1, num_stations_gather(k)
      call ASDF_create_stations_group_f(waveforms_grp,   &
           trim(network_names_gather(j, k)) // "." //      &
           trim(station_names_gather(j,k)) // C_NULL_CHAR, &
           trim(station_xml) // C_NULL_CHAR,             &
           station_grps_gather(j, k))

      do  i = 1, num_channels_per_station
        ! Generate unique dummy waveform names
        write(waveform_name, '(a,i0.2)') &
           trim(network_names_gather(j,k)) // "." //      &
           trim(station_names_gather(j,k)) // "." // "BH", myrank !trim(asdf_container%component_array(i))

        ! Create the dataset where waveform will be written later on.
        call ASDF_define_waveform_f(station_grps_gather(j,k), &
             nsamples, start_time, sampling_rate, &
             trim(event_name) // C_NULL_CHAR, &
             trim(waveform_name) // C_NULL_CHAR, &
             data_ids(i, j, k))
      enddo
    enddo
  enddo

  print *, "writing waveforms"
  do j = 1, num_stations
   do i = 1, num_channels_per_station
      call ASDF_write_full_waveform_f(data_ids(i, j, myrank+1), &
                                      waveforms(:, i, j), ier)
    enddo
  enddo

  !--------------------------------------------------------
  ! Clean up
  !--------------------------------------------------------

  do k = 1, mysize
    do j = 1, num_stations_gather(k)
      call ASDF_close_group_f(station_grps_gather(j, k), ier)
      do i = 1, num_channels_per_station
        call ASDF_close_dataset_f(data_ids(i, j, k), ier)
      enddo
    enddo
  enddo

  call ASDF_close_group_f(waveforms_grp, ier)
  call ASDF_finalize_hdf5_f(ier);

  deallocate(data_ids)
  deallocate(station_grps_gather)
  deallocate(station_names_gather)
  deallocate(network_names_gather)
  deallocate(num_stations_gather)

  deallocate(waveforms)
  deallocate(stations_names)
  deallocate(networks_names)

end subroutine write_asdf

from django.urls import path
from . import views

app_name = 'organisations'

urlpatterns = [
    # Org CRUD
    path('',                                            views.OrganisationListView.as_view(),    name='org-list'),
    path('mine/',                                       views.MyOrganisationsView.as_view(),     name='my-orgs'),
    path('<int:pk>/',                                   views.OrganisationDetailView.as_view(),  name='org-detail'),

    # Members
    path('<int:org_pk>/members/',                       views.MemberListView.as_view(),          name='member-list'),
    path('<int:org_pk>/members/add/',                   views.AddMemberView.as_view(),           name='member-add'),
    path('<int:org_pk>/members/<int:user_pk>/',         views.RemoveMemberView.as_view(),        name='member-remove'),

    # Invitations (manager-scoped)
    path('<int:org_pk>/invitations/',                   views.InvitationListView.as_view(),      name='invitation-list'),
    path('<int:org_pk>/invitations/send/',              views.SendInvitationView.as_view(),      name='invitation-send'),
    path('<int:org_pk>/invitations/bulk/',              views.BulkInviteView.as_view(),          name='invitation-bulk'),
    path('<int:org_pk>/invitations/<int:inv_pk>/',      views.CancelInvitationView.as_view(),    name='invitation-cancel'),
]
